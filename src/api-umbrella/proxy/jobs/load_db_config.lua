local _M = {}

local active_config = require "api-umbrella.proxy.models.active_config"
local db_config = require "api-umbrella.proxy.models.db_config"
local interval_lock = require "api-umbrella.utils.interval_lock"
local load_backends = require "api-umbrella.proxy.load_backends"
local lock = require "resty.lock"
local utils = require "api-umbrella.proxy.utils"

local ERR = ngx.ERR
local get_packed = utils.get_packed
local log = ngx.log
local new_timer = ngx.timer.at

local delay = 0.3  -- in seconds

local function restore_active_config_backends_after_reload()
  local restore_lock = lock:new("locks", { ["timeout"] = 10 })
  local _, lock_err = restore_lock:lock("restore_active_config_backends:" .. WORKER_GROUP_ID)
  if lock_err then
    return
  end

  if not ngx.shared.active_config:get("upstreams_setup_complete:" .. WORKER_GROUP_ID) then
    local existing_active_config = get_packed(ngx.shared.active_config, "packed_data")
    if existing_active_config and existing_active_config["apis"] then
      load_backends.setup_backends(existing_active_config["apis"])
    end
  end

  local ok, unlock_err = restore_lock:unlock()
  if not ok then
    ngx.log(ngx.ERR, "failed to unlock: ", unlock_err)
  end
end

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
  local last_fetched_version = ngx.shared.active_config:get("db_version") or 0

  -- If this set of worker processes hasn't been setup yet (initial boot or
  -- after reload), force a re-fetch of the latest database config.
  if not ngx.shared.active_config:get("worker_group_setup_complete:" .. WORKER_GROUP_ID) then
    last_fetched_version = 0
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
    active_config.set(db_result)
  elseif not ngx.shared.active_config:get("worker_group_setup_complete:" .. WORKER_GROUP_ID) then
    -- If this set of worker processes hasn't been setup yet (initial boot or
    -- after reload), then still perform the active config setup despite no
    -- database config being present (there is still the file-based config to
    -- read in).
    active_config.set({})
  end

  if last_fetched_at then
    ngx.shared.active_config:set("db_config_last_fetched_at", last_fetched_at)
  end
end

local function setup(premature)
  if premature then
    return
  end

  local ok, err = pcall(restore_active_config_backends_after_reload)
  if not ok then
    ngx.log(ngx.ERR, "failed to run api load cycle: ", err)
  end

  interval_lock.repeat_with_mutex('load_db_config_check', delay, do_check)
end

function _M.spawn()
  local ok, err = new_timer(0, setup)
  if not ok then
    log(ERR, "failed to create timer: ", err)
    return
  end
end

return _M
