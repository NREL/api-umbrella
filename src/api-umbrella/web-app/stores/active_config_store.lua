local build_web_app_active_config = require "api-umbrella.utils.active_config_store.build_web_app_active_config"
local fetch_published_config_for_setting_active_config = require "api-umbrella.utils.active_config_store.fetch_published_config_for_setting_active_config"
local mlcache = require "resty.mlcache"
local polling_set_active_config = require "api-umbrella.utils.active_config_store.polling_set_active_config"

local _M = {}

local function fetch_active_config(last_fetched_version)
  return fetch_published_config_for_setting_active_config(last_fetched_version, function(published_config)
    local active_config = build_web_app_active_config(published_config)
    return active_config, active_config["db_version"]
  end)
end

local cache, cache_err = mlcache.new("active_config", "active_config", {
  lru_size = 1000,
  ttl = 0,
  resurrect_ttl = 60 * 60 * 24,
  neg_ttl = 60 * 60 * 24,
  shm_locks = "active_config_locks",
  ipc_shm = "active_config_ipc",
})
if not cache then
  ngx.log(ngx.ERR, "failed to create active_config mlcache: ", cache_err)
  return nil
end

function _M.get()
  local active_config, err = cache:get("active_config", nil, fetch_active_config)
  if err then
    ngx.log(ngx.ERR, "active config cache lookup failed: ", err)
    return nil
  end

  return active_config
end

function _M.poll_for_update()
  return polling_set_active_config(cache, function(last_fetched_version)
    local active_config = fetch_active_config(last_fetched_version)
    return active_config
  end)
end

function _M.refresh_local_cache()
  local _, update_err = cache:update()
  if update_err then
    ngx.log(ngx.ERR, "active_config cache update failed: ", update_err)
  end
end

return _M
