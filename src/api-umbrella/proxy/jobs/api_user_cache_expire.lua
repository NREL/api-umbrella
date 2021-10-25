local _M = {}

local cache = require("api-umbrella.proxy.user_store").cache
local encryptor = require "api-umbrella.utils.encryptor"
local int64 = require "api-umbrella.utils.int64"
local interval_lock = require "api-umbrella.utils.interval_lock"
local pg_utils = require "api-umbrella.utils.pg_utils"

local jobs = ngx.shared.jobs

local delay = 1 -- in seconds

local function do_check()
  local last_fetched_version = jobs:get("api_users_last_fetched_version") or int64.MIN_VALUE_STRING
  local results, err = pg_utils.query("SELECT id, version, api_key_encrypted, api_key_encrypted_iv FROM api_users WHERE version > :version ORDER BY version DESC", { version = last_fetched_version }, { quiet = true })
  if not results then
    ngx.log(ngx.ERR, "failed to fetch users from database: ", err)
    return nil
  end

  for index, row in ipairs(results) do
    if index == 1 then
      last_fetched_version = int64.to_string(row["version"])
    end

    local api_key
    if row["api_key_encrypted"] and row["api_key_encrypted_iv"] and row["id"] then
      api_key = encryptor.decrypt(row["api_key_encrypted"], row["api_key_encrypted_iv"], row["id"])
    end
    if api_key then
      local _, delete_err = cache:delete(api_key)
      if delete_err then
        ngx.log(ngx.ERR, "api_users cache delete failed: ", delete_err)
      end
    else
      ngx.log(ngx.ERR, "Could not decrypt api key for cache invalidation: ", row["id"])
    end
  end

  local set_ok, set_err, set_forcible = jobs:set("api_users_last_fetched_version", last_fetched_version)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'api_users_last_fetched_version' in 'jobs' shared dict: ", set_err)
  elseif set_forcible then
    ngx.log(ngx.WARN, "forcibly set 'api_users_last_fetched_version' in 'jobs' shared dict (shared dict may be too small)")
  end
end

function _M.spawn()
  interval_lock.repeat_with_mutex("api_user_cache_expire", delay, do_check)
end

return _M
