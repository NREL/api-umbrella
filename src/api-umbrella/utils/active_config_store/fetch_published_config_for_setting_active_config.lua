local fetch_latest_published_config = require "api-umbrella.utils.active_config_store.fetch_latest_published_config"
local worker_group_config_refresh_complete = require("api-umbrella.utils.worker_group").config_refresh_complete

local jobs_dict = ngx.shared.jobs

return function(last_fetched_version, callback)
  local published_config, err = fetch_latest_published_config(last_fetched_version)
  if err then
    ngx.log(ngx.ERR, "failed to fetch published config from database: ", err)
  end

  -- If we're polling for newer database config (last_fetched_version is
  -- present, since we're looking for something newer), and no new results are
  -- found, then return immediately so we don't replace the config with an
  -- identical version.
  if not published_config and last_fetched_version then
    return nil
  end

  local active_config_value, db_version = callback(published_config)

  worker_group_config_refresh_complete()

  local set_ok, set_err, set_forcible = jobs_dict:set("active_config_store_last_fetched_version", db_version or "0")
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'active_config_store_last_fetched_version' in 'jobs' shared dict: ", set_err)
  elseif set_forcible then
    ngx.log(ngx.WARN, "forcibly set 'active_config_store_last_fetched_version' in 'jobs' shared dict (shared dict may be too small)")
  end

  return active_config_value
end
