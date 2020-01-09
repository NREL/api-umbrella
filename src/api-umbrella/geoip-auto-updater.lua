local config = require "api-umbrella.proxy.models.file_config"
local geoip_download_if_missing_or_old = require("api-umbrella.utils.geoip").download_if_missing_or_old
local run_command = require "api-umbrella.utils.run_command"

local function update()
  print("UPDATE!")
  local status, err = geoip_download_if_missing_or_old(config)
  if err then
    ngx.log(ngx.ERR, "GeoIP Database download failed: ", err)
  elseif status == "changed" then
    local _, _, reload_err = run_command({ "api-umbrella", "reload", "--router" })
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
