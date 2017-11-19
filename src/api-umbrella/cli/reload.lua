local path = require "pl.path"
local run_command = require "api-umbrella.utils.run_command"
local setup = require "api-umbrella.cli.setup"
local status = require "api-umbrella.cli.status"
local types = require "pl.types"

local is_empty = types.is_empty

local function reload_perp(perp_base)
  local _, _, err = run_command("perphup " .. perp_base)
  if err then
    print("Failed to reload perp\n" .. err)
    os.exit(1)
  end
end

local function reload_trafficserver(perp_base)
  local _, _, err = run_command("perpctl -b " .. perp_base .. " hup trafficserver")
  if err then
    print("Failed to reload trafficserver\n" .. err)
    os.exit(1)
  end
end

local function reload_nginx(perp_base)
  local _, _, err = run_command("perpctl -b " .. perp_base .. " hup nginx")
  if err then
    print("Failed to reload nginx\n" .. err)
    os.exit(1)
  end
end

local function reload_nginx_web_app(perp_base)
  local _, _, err = run_command("perpctl -b " .. perp_base .. " hup nginx-web-app")
  if err then
    print("Failed to reload nginx\n" .. err)
    os.exit(1)
  end
end

local function reload_dev_env_ember_server(perp_base)
  local _, _, err = run_command("perpctl -b " .. perp_base .. " term dev-env-ember-server")
  if err then
    print("Failed to reload dev-env-ember-server\n" .. err)
    os.exit(1)
  end
end

local function reload_nginx_reloader(perp_base)
  local _, _, err = run_command("perpctl -b " .. perp_base .. " term nginx-reloader")
  if err then
    print("Failed to reload nginx-reloader\n" .. err)
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
  local perp_base = path.join(config["etc_dir"], "perp")

  reload_perp(perp_base)

  if config["_service_router_enabled?"] and (is_empty(options) or options["router"]) then
    reload_trafficserver(perp_base)
    reload_nginx(perp_base)
    reload_nginx_web_app(perp_base)

    if config["_service_nginx_reloader_enabled?"] then
      reload_nginx_reloader(perp_base)
    end
  end

  if config["app_env"] == "development" then
    reload_dev_env_ember_server(perp_base)
  end
end
