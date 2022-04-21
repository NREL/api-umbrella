local path_join = require "api-umbrella.utils.path_join"
local setup = require "api-umbrella.cli.setup"
local shell_blocking_capture_combined = require("shell-games").capture_combined
local status = require "api-umbrella.cli.status"

local function reload_perp(perp_base)
  local _, err = shell_blocking_capture_combined({ "perphup", perp_base })
  if err then
    print("Failed to reload perp\n" .. err)
    os.exit(1)
  end
end

local function reload_trafficserver(config)
  local _, err = shell_blocking_capture_combined({ "env", "TS_ROOT=" .. config["root_dir"], "traffic_ctl", "config", "reload" })
  if err then
    print("Failed to reload trafficserver\n" .. err)
    os.exit(1)
  end
end

local function reload_nginx(perp_base)
  local _, err = shell_blocking_capture_combined({ "perpctl", "-b", perp_base, "hup", "nginx" })
  if err then
    print("Failed to reload nginx\n" .. err)
    os.exit(1)
  end
end

local function reload_nginx_web_app(perp_base)
  local _, err = shell_blocking_capture_combined({ "perpctl", "-b", perp_base, "hup", "nginx-web-app" })
  if err then
    print("Failed to reload nginx\n" .. err)
    os.exit(1)
  end
end

local function reload_nginx_auto_ssl(perp_base)
  local _, err = shell_blocking_capture_combined({ "perpctl", "-b", perp_base, "hup", "nginx-auto-ssl" })
  if err then
    print("Failed to reload nginx\n" .. err)
    os.exit(1)
  end
end

local function reload_geoip_auto_updater(perp_base)
  local _, err = shell_blocking_capture_combined({ "perpctl", "-b", perp_base, "term", "geoip-auto-updater" })
  if err then
    print("Failed to reload geoip-auto-updater\n" .. err)
    os.exit(1)
  end
end

local function reload_dev_env_ember_server(perp_base)
  local _, err = shell_blocking_capture_combined({ "perpctl", "-b", perp_base, "term", "dev-env-ember-server" })
  if err then
    print("Failed to reload dev-env-ember-server\n" .. err)
    os.exit(1)
  end
end

return function(options)
  options["reload"] = nil

  local running = status()
  if not running then
    print("api-umbrella is stopped")
    os.exit(7)
  end

  local config = setup()
  local perp_base = path_join(config["etc_dir"], "perp")

  reload_perp(perp_base)

  if config["_service_web_enabled?"] then
    reload_nginx_web_app(perp_base)
  end

  if config["_service_router_enabled?"] then
    reload_trafficserver(config)
    reload_nginx(perp_base)

    if config["geoip"]["_enabled"] then
      reload_geoip_auto_updater(perp_base)
    end
  end

  if config["_service_auto_ssl_enabled?"] then
    reload_nginx_auto_ssl(perp_base)
  end

  if config["app_env"] == "development" then
    reload_dev_env_ember_server(perp_base)
  end
end
