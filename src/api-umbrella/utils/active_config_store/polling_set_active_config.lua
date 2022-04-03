local worker_group = require "api-umbrella.utils.worker_group"

local jobs_dict = ngx.shared.jobs
local worker_group_is_latest = worker_group.is_latest
local worker_group_needs_config_refresh = worker_group.needs_config_refresh

return function(cache, callback)
  -- If this worker process isn't part of the latest group, then don't perform
  -- any further processing. This prevents older workers that may be in the
  -- process of shutting down after a SIGHUP reload from performing a check and
  -- possibly overwriting newer config (since the file config is only read in
  -- on SIGHUPs and may differ between the older and newer worker groups).
  if not worker_group_is_latest() then
    return
  end

  -- Get the latest version fetched from the database so we can look for newer
  -- versions during polling.
  local last_fetched_version, last_fetched_version_err = jobs_dict:get("active_config_store_last_fetched_version")
  if last_fetched_version_err then
    ngx.log(ngx.ERR, "Error fetching last_fetched_version: ", last_fetched_version_err)
    return
  elseif not last_fetched_version then
    -- If the active config hasn't been set yet, then this means the first
    -- fetch (triggered on demand by active_config_store.get) yet completed, so
    -- return and wait for that to complete, since there's no need to poll for
    -- a newer version with nothing stored yet.
    return
  end

  -- If this set of worker processes hasn't been setup yet (initial boot or
  -- after reload), force a re-fetch of the latest database config so that any
  -- updated file config also gets read in. By setting last_fetched_version to
  -- nil, the fetch callback will look for any version and process it like the
  -- very first fetch.
  if worker_group_needs_config_refresh() then
    last_fetched_version = nil
  end

  local new_active_config_value = callback(last_fetched_version)
  if new_active_config_value then
    -- TODO: Check size to fit in memory.
    cache:set("active_config", nil, new_active_config_value)
  end
end
