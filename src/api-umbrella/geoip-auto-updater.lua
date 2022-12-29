local config = require("api-umbrella.utils.load_config")()
local geoip_download_if_missing_or_old = require("api-umbrella.utils.geoip").download_if_missing_or_old
local shell_blocking_capture_combined = require("shell-games").capture_combined

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

local _, err = ngx.timer.every(config["geoip"]["db_update_frequency"], update)
if err then
  ngx.log(ngx.ERR, "Failed to create update timer: ", err)
end

while true do
  ngx.sleep(3600)
end
