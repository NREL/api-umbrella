local write_config_files = require "api-umbrella.cli.write_config_files"
local config = require("api-umbrella.utils.load_config")()
local geoip_download_if_missing_or_old = require("api-umbrella.utils.geoip").download_if_missing_or_old
local shell_blocking_capture_combined = require("shell-games").capture_combined
local unistd = require "posix.unistd"

local sleep = ngx.sleep

local function permission_check()
  local effective_uid = unistd.geteuid()
  if config["user"] then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to change user to '" .. config["user"] .. "'")
      os.exit(1)
    end

    local result, err = shell_blocking_capture_combined({ "getent", "passwd", config["user"] })
    if result["status"] == 2 and result["output"] == "" then
      print("User '" .. (config["user"] or "") .. "' does not exist")
      os.exit(1)
    elseif err then
      print(err)
      os.exit(1)
    end
  end

  if config["group"] then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to change group to '" .. config["group"] .. "'")
      os.exit(1)
    end

    local result, err = shell_blocking_capture_combined({ "getent", "group", config["group"] })
    if result["status"] == 2 and result["output"] == "" then
      print("Group '" .. (config["group"] or "") .. "' does not exist")
      os.exit(1)
    elseif err then
      print(err)
      os.exit(1)
    end
  end

  if config["http_port"] < 1024 or config["https_port"] < 1024 then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to use http ports below 1024")
      os.exit(1)
    end
  end

  if effective_uid == 0 and config["app_env"] ~= "test" then
    if not config["user"] or not config["group"] then
      print("Must define a user and group to run worker processes as when starting with with super-user privileges")
      os.exit(1)
    end
  end
end

local function ensure_geoip_db()
  config["geoip"]["_enabled"] = false
  config["geoip"]["_auto_updater_enabled"] = false

  -- Try to wait for geoip to download, since there may be race conditions on
  -- startup in downloading via http proxy that's also starting up.
  local _
  local geoip_err
  local timeout_at = ngx.now() + 60
  repeat
    _, geoip_err = geoip_download_if_missing_or_old(config)
    if geoip_err then
      sleep(1)
    end
  until not geoip_err or ngx.now() > timeout_at

  if geoip_err then
    ngx.log(ngx.ERR, "geoip database download failed: ", geoip_err)
  else
    config["geoip"]["_enabled"] = true

    if config["geoip"]["db_update_frequency"] ~= false then
      config["geoip"]["_auto_updater_enabled"] = true
    end
  end
end

return function()
  permission_check()
  write_config_files.prepare()
  ensure_geoip_db()
  write_config_files.all_steps()
end
