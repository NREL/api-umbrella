local path = require "pl.path"
local run_command = require "api-umbrella.utils.run_command"
local setup = require "api-umbrella.cli.setup"
local status = require "api-umbrella.cli.status"

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

return function()
  local running = status()
  if not running then
    print("api-umbrella is stopped")
    os.exit(1)
  end

  local config = setup()
  local perp_base = path.join(config["etc_dir"], "perp")
  reload_perp(perp_base)
  reload_trafficserver(perp_base)
  reload_nginx(perp_base)
end
