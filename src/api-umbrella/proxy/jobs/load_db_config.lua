local _M = {}

local db_config = require "api-umbrella.proxy.models.db_config"
local int64 = require "api-umbrella.utils.int64"
local interval_lock = require "api-umbrella.utils.interval_lock"

local ERR = ngx.ERR
local log = ngx.log
local new_timer = ngx.timer.at

local delay = 0.3  -- in seconds
local callback

local function do_check()
  -- If this worker process isn't part of the latest group, then don't perform
  -- any further processing. This prevents older workers that may be in the
  -- process of shutting down after a SIGHUP reload from performing a check and
  -- possibly overwriting newer config (since the file config is only read in
  -- on SIGHUPs and may differ between the older and newer worker groups).
  if WORKER_GROUP_ID < ngx.shared.active_config:get("worker_group_id") then
    return
  end

  -- Query for database config versions that are newer than the previously
  -- fetched version.
  local last_fetched_version = ngx.shared.active_config:get("db_version") or int64.MIN_VALUE_STRING

  -- If this set of worker processes hasn't been setup yet (initial boot or
  -- after reload), force a re-fetch of the latest database config.
  if not ngx.shared.active_config:get("worker_group_setup_complete:" .. WORKER_GROUP_ID) then
    last_fetched_version = int64.MIN_VALUE_STRING
  end

  -- Perform the database fetch.
  local last_fetched_at = ngx.now()
  local db_result, err = db_config.fetch(last_fetched_version)

  if err then
    -- If an error occurred while fetching the database config, log the error,
    -- but keep any existing configuration in place.
    ngx.log(ngx.ERR, "failed to fetch config from database: ", err)
    last_fetched_at = nil
  elseif db_result and db_result["version"] then
    -- If the database contained a new config version then do the necessary
    -- processing to setup the internal active config.
    callback(db_result)
  elseif not ngx.shared.active_config:get("worker_group_setup_complete:" .. WORKER_GROUP_ID) then
    -- If this set of worker processes hasn't been setup yet (initial boot or
    -- after reload), then still perform the active config setup despite no
    -- database config being present (there is still the file-based config to
    -- read in).
    callback({})
  end

  local set_ok, set_err = ngx.shared.active_config:safe_set("worker_group_setup_complete:" .. WORKER_GROUP_ID, true)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'worker_group_setup_complete' in 'active_config' shared dict: ", set_err)
  end

  if last_fetched_at then
    set_ok, set_err = ngx.shared.active_config:safe_set("db_config_last_fetched_at", last_fetched_at)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set 'db_config_last_fetched_at' in 'active_config' shared dict: ", set_err)
    end
  end
end

local function setup(premature)
  if premature then
    return
  end

  interval_lock.repeat_with_mutex('load_db_config_check', delay, do_check)
end

function _M.spawn(callback_arg)
  callback = callback_arg
  local ok, err = new_timer(0, setup)
  if not ok then
    log(ERR, "failed to create timer: ", err)
    return
  end
end

return _M
