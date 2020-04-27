local config = require "api-umbrella.proxy.models.file_config"
local disposable_email_domains_pull = require("api-umbrella.utils.disposable_email_domains").pull
local geoip_download_if_missing_or_old = require("api-umbrella.utils.geoip").download_if_missing_or_old
local shell_blocking_capture_combined = require("shell-games").capture_combined

local function update_geoip()
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

local function update_disposable_email_domains()
  ngx.log(ngx.NOTICE, "Checking for disposable email domains database updates...")
  local status, err = disposable_email_domains_pull(config)
  if err then
    ngx.log(ngx.ERR, "Disposable email domains database download failed: ", err)
  elseif status == "changed" then
    local _, reload_err = shell_blocking_capture_combined({ "api-umbrella", "reload" })
    if reload_err then
      ngx.log(ngx.ERR, "Failed to reload api-umbrella: ", reload_err)
    else
      ngx.log(ngx.NOTICE, "Reloaded api-umbrella")
    end
  end
end

if config["geoip"]["_enabled"] then
  local _, geoip_timer_err = ngx.timer.every(config["geoip"]["db_update_frequency"], update_geoip)
  if geoip_timer_err then
    ngx.log(ngx.ERR, "Failed to create update timer: ", geoip_timer_err)
  end
end

if config["web"]["email"]["auto_update_disposable_domains"] then
  local _, disposable_email_domains_timer_err = ngx.timer.every(config["web"]["email"]["auto_update_disposable_domains_frequency"], update_disposable_email_domains)
  if disposable_email_domains_timer_err then
    ngx.log(ngx.ERR, "Failed to create update timer: ", disposable_email_domains_timer_err)
  end
end

while true do
  ngx.sleep(3600)
end
