local build_web_app_active_config = require "api-umbrella.utils.active_config_store.build_web_app_active_config"
local fetch_latest_published_config = require "api-umbrella.utils.active_config_store.fetch_latest_published_config"
local mlcache = require "resty.mlcache"

local jobs_dict = ngx.shared.jobs

local _M = {}

local function fetch_active_config(last_fetched_version)
  local published_config, err = fetch_latest_published_config(last_fetched_version)
  if err then
    ngx.log(ngx.ERR, "failed to fetch published config from database: ", err)
  end

  if not published_config and last_fetched_version then
    return nil
  end

  local active_config = build_web_app_active_config(published_config)

  local set_ok, set_err, set_forcible = jobs_dict:set("active_config_store_last_fetched_version", active_config["db_version"] or 0)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'active_config_store_last_fetched_version' in 'jobs' shared dict: ", set_err)
  elseif set_forcible then
    ngx.log(ngx.WARN, "forcibly set 'active_config_store_last_fetched_version' in 'jobs' shared dict (shared dict may be too small)")
  end

  return active_config
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
  local last_fetched_version, last_fetched_version_err = jobs_dict:get("active_config_store_last_fetched_version")
  if last_fetched_version_err then
    ngx.log(ngx.ERR, "Error fetching last_fetched_version: ", last_fetched_version_err)
    return
  elseif not last_fetched_version then
    -- If the active config hasn't been set yet, then this means the initial
    -- fetching hasn't yet completed, so return and wait for that to complete.
    return
  end

  local active_config = fetch_active_config(last_fetched_version)
  if active_config then
    cache:set("active_config", nil, active_config)
  end
end

function _M.refresh_local_cache()
  local _, update_err = cache:update()
  if update_err then
    ngx.log(ngx.ERR, "active_config cache update failed: ", update_err)
  end
end

return _M
