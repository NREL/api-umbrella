local shared_dict_retry = require "api-umbrella.utils.shared_dict_retry"

local shared_dict_retry_incr = shared_dict_retry.incr
local shared_dict_retry_set = shared_dict_retry.set

local _M = {}

local jobs_dict = ngx.shared.jobs
local worker_group_id

-- Generate a unique ID to represent this group of worker processes. This value
-- will be the same amongst all the subsequently inited workers, but the value
-- will differ for each new group of worker processes that get started when
-- nginx is reloaded (SIGHUP).
--
-- This is used to deal with race conditions during reloads between the nginx
-- workers shutting down and the new workers starting up.
function _M.init()
  local incr_err
  worker_group_id, incr_err = shared_dict_retry_incr(jobs_dict, "worker_group_id", 1)
  if incr_err == "not found" then
    worker_group_id = 1
    local set_ok, set_err, set_forcible = shared_dict_retry_set(jobs_dict, "worker_group_id", worker_group_id)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set 'worker_group_id' in 'jobs' shared dict: ", set_err)
    elseif set_forcible then
      ngx.log(ngx.WARN, "forcibly set 'worker_group_id' in 'jobs' shared dict (shared dict may be too small)")
    end
  elseif incr_err then
    ngx.log(ngx.ERR, "worker_group_id incr err: ", incr_err)
  end

  local set_ok, set_err, set_forcible = shared_dict_retry_set(jobs_dict, "worker_group_needs_config_refresh", true)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'worker_group_needs_config_refresh' in 'jobs' shared dict: ", set_err)
  elseif set_forcible then
    ngx.log(ngx.WARN, "forcibly set 'worker_group_needs_config_refresh' in 'jobs' shared dict (shared dict may be too small)")
  end

  set_ok, set_err, set_forcible = shared_dict_retry_set(jobs_dict, "opensearch_templates_created", false)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'opensearch_templates_created' in 'jobs' shared dict: ", set_err)
  elseif set_forcible then
    ngx.log(ngx.WARN, "forcibly set 'opensearch_templates_created' in 'jobs' shared dict (shared dict may be too small)")
  end
end

function _M.is_latest()
  local latest_worker_group_id, err = jobs_dict:get("worker_group_id")
  if err then
    ngx.log(ngx.ERR, "Error fetching worker_group_id: ", err)
    return false
  end

  return latest_worker_group_id == worker_group_id
end

function _M.needs_config_refresh()
  local needs_config_refresh, err = jobs_dict:get("worker_group_needs_config_refresh")
  if err then
    ngx.log(ngx.ERR, "Error fetching worker_group_id: ", err)
    return false
  end

  return needs_config_refresh
end

function _M.config_refresh_complete()
  if not _M.is_latest() then
    ngx.log(ngx.NOTICE, "Skipping setting 'worker_group_needs_config_refresh' in 'jobs' shared dict since worker group is no longer the latest")
    return
  end

  local set_ok, set_err, set_forcible = shared_dict_retry_set(jobs_dict, "worker_group_needs_config_refresh", false)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'worker_group_needs_config_refresh' in 'jobs' shared dict: ", set_err)
  elseif set_forcible then
    ngx.log(ngx.WARN, "forcibly set 'worker_group_needs_config_refresh' in 'jobs' shared dict (shared dict may be too small)")
  end
end

return _M
