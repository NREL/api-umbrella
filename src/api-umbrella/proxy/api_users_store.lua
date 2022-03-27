local api_key_prefixer = require("api-umbrella.utils.api_key_prefixer").prefix
local cache_computed_settings = require("api-umbrella.proxy.utils").cache_computed_settings
local config = require "api-umbrella.proxy.models.file_config"
local encryptor = require "api-umbrella.utils.encryptor"
local hmac = require "api-umbrella.utils.hmac"
local int64_to_string = require("api-umbrella.utils.int64").to_string
local mlcache = require "resty.mlcache"
local mutex_exec = require("api-umbrella.utils.interval_lock").mutex_exec
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"
local pg_utils = require "api-umbrella.utils.pg_utils"

local api_key_cache_enabled = config["gatekeeper"]["api_key_cache"]
local api_key_max_length = config["gatekeeper"]["api_key_max_length"]
local api_key_min_length = config["gatekeeper"]["api_key_min_length"]
local cursor = pg_utils.cursor
local jobs = ngx.shared.jobs
local last_fetched_version_set_once = false
local query = pg_utils.query

local _M = {}

local cache, cache_err = mlcache.new("u", "api_users", {
  lru_size = 1000,
  ttl = 60 * 60 * 24,
  resurrect_ttl = 60 * 60 * 24,
  neg_ttl = 60 * 60 * 24,
  shm_miss = "api_users_misses",
  shm_locks = "api_users_locks",
  ipc_shm = "api_users_ipc",
})
if cache_err then
  ngx.log(ngx.ERR, "failed to create api_users mlcache: ", cache_err)
end

local function fetch_user(api_key_prefix, api_key)
  -- Before adding data into the cache for the first time, figure out the
  -- version that should be used for future polling to find stale cache items.
  if not last_fetched_version_set_once then
    local _, err = _M.set_initial_last_fetched_version()
    if err then
      ngx.log(ngx.ERR, "failed calling set_initial_last_fetched_version:", err)
    else
      last_fetched_version_set_once = true
    end
  end

  -- Since api_key_prefix has a uniqueness constraint in the database, we can
  -- do the initial lookup based on this. We'll still need to validate the full
  -- key afterwards, but this makes lookups for non-existent keys cheaper,
  -- since we don't have to perform the hash if the prefix doesn't exist.
  local result, err = query("SELECT * FROM api_users_flattened WHERE api_key_prefix = :api_key_prefix", { api_key_prefix = api_key_prefix })
  if not result then
    ngx.log(ngx.ERR, "failed to fetch user from database: ", err)
    return nil
  end

  local user = result[1]
  if not user then
    return nil
  end

  -- Verify that the record with the matching key prefix actually matches the
  -- full API key (via the hash).
  local api_key_hash = hmac(api_key)
  if user["api_key_hash"] ~= api_key_hash then
    return nil
  end

  if user["settings"] then
    nillify_json_nulls(user["settings"])
    cache_computed_settings(user["settings"])
  end

  -- Remove pieces that don't need to be stored.
  user["api_key_prefix"] = nil
  user["api_key_hash"] = nil

  return user
end

function _M.get(api_key)
  -- Validate that the key being passed in isn't too short or too long to avoid
  -- unnecessary lookups/caching for obviously invalid values.
  local len = string.len(api_key)
  if len < api_key_min_length or len > api_key_max_length then
    return nil
  end

  local api_key_prefix = api_key_prefixer(api_key)

  if not api_key_cache_enabled then
    return fetch_user(api_key_prefix, api_key)
  end

  local user, err = cache:get(api_key, nil, fetch_user, api_key_prefix, api_key)
  if err then
    ngx.log(ngx.ERR, "api key cache lookup failed: ", err)
    return nil
  end

  return user
end

function _M.set_initial_last_fetched_version()
  return mutex_exec("api_users_store_set_initial_last_fetched_version", function()
    -- Check to see if the shared dict value has already been set (possibly by
    -- another process). If it has, no need to proceed.
    local last_fetched_version, last_fetched_version_err = jobs:get("api_users_store_last_fetched_version")
    if last_fetched_version_err then
      return false, "failed to fetch api_users_store_last_fetched_version: " .. last_fetched_version_err
    end
    if last_fetched_version then
      return
    end

    -- Find the maximum version in the database so we know where to start
    -- polling from.
    local result, result_err = query("SELECT MAX(version) AS max_version FROM api_users")
    if result_err then
      return false, "failed to fetch max version from database: " .. result_err
    end

    -- If there are no versions available, then this indicates that the
    -- database is empty, so we return this as a special value so we know to
    -- poll for any changes (since the version number might be starting at the
    -- minimum integer number).
    local max_version
    if not result[1] or not result[1]["max_version"] then
      max_version = "NO_RECORDS"
    else
      max_version = int64_to_string(result[1]["max_version"])
    end

    local add_ok, add_err, add_forcible = jobs:add("api_users_store_last_fetched_version", max_version)
    if not add_ok then
      ngx.log(ngx.ERR, "failed to add 'api_users_store_last_fetched_version' in 'jobs' shared dict: ", add_err)
    elseif add_forcible then
      ngx.log(ngx.WARN, "forcibly add 'api_users_store_last_fetched_version' in 'jobs' shared dict (shared dict may be too small)")
    end
  end)
end

function _M.delete_stale_cache()
  -- Find the last version we've previously checked and performed expirations
  -- on.
  local last_fetched_version, last_fetched_version_err = jobs:get("api_users_store_last_fetched_version")
  if last_fetched_version_err then
    ngx.log(ngx.ERR, "Error fetching last_fetched_version: ", last_fetched_version_err)
    return
  elseif not last_fetched_version then
    -- If no API keys have ever been cached then there's no need to check for
    -- any newer versions.
    return
  end

  -- Construct the query to find newer records.
  local select_sql = {}
  local select_values = {}
  table.insert(select_sql, "SELECT id, version, api_key_encrypted, api_key_encrypted_iv FROM api_users")
  -- If the last version is the special "NO_RECORDS" value, then this indicates
  -- no records existed at startup, so we should poll for any changes,
  -- regardless of version.
  if last_fetched_version ~= "NO_RECORDS" then
    table.insert(select_sql, "WHERE version > :version")
    select_values["version"] = last_fetched_version
  end
  table.insert(select_sql, "ORDER BY version DESC")
  select_sql = table.concat(select_sql, " ")

  -- Loop over results in a cursor to prevent large batches of
  -- changes/insertions from consuming lots of local memory.
  local new_last_fetched_version
  local _, cursor_err = cursor(select_sql, select_values, 1000, { quiet = true }, function(results)
    for _, row in ipairs(results) do
      if not new_last_fetched_version then
        new_last_fetched_version = int64_to_string(row["version"])
      end

      local api_key
      if row["api_key_encrypted"] and row["api_key_encrypted_iv"] and row["id"] then
        api_key = encryptor.decrypt(row["api_key_encrypted"], row["api_key_encrypted_iv"], row["id"])
      end
      if api_key then
        local _, delete_err = cache:delete(api_key)
        if delete_err then
          ngx.log(ngx.ERR, "api users cache delete failed: ", delete_err)
        end
      else
        ngx.log(ngx.ERR, "Could not decrypt api key for cache invalidation: ", row["id"])
      end
    end
  end)
  if cursor_err then
    ngx.log(ngx.ERR, "cursor error: ", cursor_err)
    return
  end

  if new_last_fetched_version then
    local set_ok, set_err, set_forcible = jobs:set("api_users_store_last_fetched_version", new_last_fetched_version)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set 'api_users_store_last_fetched_version' in 'jobs' shared dict: ", set_err)
    elseif set_forcible then
      ngx.log(ngx.WARN, "forcibly set 'api_users_store_last_fetched_version' in 'jobs' shared dict (shared dict may be too small)")
    end
  end
end

function _M.refresh_local_cache()
  local _, update_err = cache:update()
  if update_err then
    ngx.log(ngx.ERR, "api users cache update failed: ", update_err)
  end
end

return _M
