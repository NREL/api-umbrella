local inspect = require "inspect"
local path = require "pl.path"
local setup = require "api-umbrella.cli.setup"
local unistd = require "posix.unistd"

local config = {}
local perp_base

local function reload_perp()
  local code = os.execute("perphup -q " .. perp_base)
  if code ~= 0 then
    print("Failed to reload perp")
    os.exit(1)
  end
end

local function reload_dnsmasq()
  local code = os.execute("perpctl -q -b " .. perp_base .. " hup dnsmasq")
  if code ~= 0 then
    print("Failed to reload dnsmasq")
    os.exit(1)
  end
end

local function reload_trafficserver()
  local code = os.execute("perpctl -q -b " .. perp_base .. " hup trafficserver")
  if code ~= 0 then
    print("Failed to reload trafficserver")
    os.exit(1)
  end
end


local function reload_nginx()
  local code = os.execute("perpctl -q -b " .. perp_base .. " hup gatekeeper-nginx")
  if code ~= 0 then
    print("Failed to reload nginx")
    os.exit(1)
  end
end

return function(options)
  config = setup()
  perp_base = path.join(config["etc_dir"], "perp")
  reload_perp()
  reload_dnsmasq()
  reload_trafficserver()
  reload_nginx()
end
