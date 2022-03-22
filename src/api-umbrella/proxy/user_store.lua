local api_key_prefixer = require("api-umbrella.utils.api_key_prefixer").prefix
local cache_computed_settings = require("api-umbrella.proxy.utils").cache_computed_settings
local config = require "api-umbrella.proxy.models.file_config"
local hmac = require "api-umbrella.utils.hmac"
local mlcache = require "resty.mlcache"
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"
local pg_utils = require "api-umbrella.utils.pg_utils"

local api_key_cache_enabled = config["gatekeeper"]["api_key_cache"]
local api_key_min_length = config["gatekeeper"]["api_key_min_length"]
local api_key_max_length = config["gatekeeper"]["api_key_max_length"]

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
if not cache then
  ngx.log(ngx.ERR, "failed to create api_users mlcache: ", cache_err)
  return nil
end

_M.cache = cache

local function fetch_user(api_key_prefix, api_key)
  -- Since api_key_prefix has a uniqueness constraint in the database, we can
  -- do the initial lookup based on this. We'll still need to validate the full
  -- key afterwards, but this makes lookups for non-existent keys cheaper,
  -- since we don't have to perform the hash if the prefix doesn't exist.
  local result, err = pg_utils.query("SELECT * FROM api_users_flattened WHERE api_key_prefix = :api_key_prefix", { api_key_prefix = api_key_prefix })
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

return _M
