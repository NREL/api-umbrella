local path = require "pl.path"
local run_command = require "api-umbrella.utils.run_command"
local setup = require "api-umbrella.cli.setup"

local config = {}
local perp_base

local function reload_perp()
  local _, _, err = run_command("perphup -q " .. perp_base)
  if err then
    print("Failed to reload perp\n" .. err)
    os.exit(1)
  end
end

local function reload_dnsmasq()
  local _, _, err = run_command("perpctl -q -b " .. perp_base .. " hup dnsmasq")
  if err then
    print("Failed to reload dnsmasq\n" .. err)
    os.exit(1)
  end
end

local function reload_trafficserver()
  local _, _, err = run_command("perpctl -q -b " .. perp_base .. " hup trafficserver")
  if err then
    print("Failed to reload trafficserver\n" .. err)
    os.exit(1)
  end
end


local function reload_nginx()
  local _, _, err = run_command("perpctl -q -b " .. perp_base .. " hup gatekeeper-nginx")
  if err then
    print("Failed to reload nginx\n" .. err)
    os.exit(1)
  end
end

return function()
  config = setup()
  perp_base = path.join(config["etc_dir"], "perp")
  reload_perp()
  reload_dnsmasq()
  reload_trafficserver()
  reload_nginx()
end
