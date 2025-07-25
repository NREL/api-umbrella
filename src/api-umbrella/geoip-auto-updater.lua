local config = require("api-umbrella.utils.load_config")()
local geoip_download_if_missing_or_old = require("api-umbrella.utils.geoip").download_if_missing_or_old
local shell_blocking_capture_combined = require("shell-games").capture_combined

local sleep = ngx.sleep

local function update()
  ngx.log(ngx.NOTICE, "Checking for geoip database updates...")
  local status, err = geoip_download_if_missing_or_old(config)
  if err then
    ngx.log(ngx.ERR, "geoip database download failed: ", err)
  elseif status == "changed" then
    local _, reload_err = shell_blocking_capture_combined({ "api-umbrella", "reload" })
    if reload_err then
      ngx.log(ngx.ERR, "Failed to reload api-umbrella: ", reload_err)
    else
      ngx.log(ngx.NOTICE, "Reloaded api-umbrella")
    end
  end
end

-- Try to wait for geoip to download on startup, since there may be race
-- conditions on startup in downloading via http proxy that's also starting up.
-- So this gives a chance for the normal api umbrella process to startup, send
-- envoy proxy config to envoy, and then this download can happen
-- asynchronously and reload the main api-umbrella process to enable geoip.
local _, geoip_err
local timeout_at = ngx.now() + 90
repeat
  _, geoip_err = update(config)
  if geoip_err then
    ngx.log(ngx.NOTICE, "failed to download geoip file, trying again: ", geoip_err)
    sleep(1)
  end
until not geoip_err or ngx.now() > timeout_at

local _, err = ngx.timer.every(config["geoip"]["db_update_frequency"], update)
if err then
  ngx.log(ngx.ERR, "Failed to create update timer: ", err)
end

while true do
  ngx.sleep(3600)
end
