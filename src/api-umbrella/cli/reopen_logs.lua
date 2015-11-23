local path = require "pl.path"
local read_config = require "api-umbrella.cli.read_config"
local run_command = require "api-umbrella.utils.run_command"
local status = require "api-umbrella.cli.status"

local function reopen_perp_logs(perp_base)
  local _, output, err = run_command("perpls -g -b " .. perp_base)
  if err then
    print("Failed to reopen logs for perp\n" .. err)
    os.exit(1)
  end

  for line in string.gmatch(output, "[^\r\n]+") do
    local service_status, service = string.match(line, "^%[(.) .-%]%s+(%S+)")
    if service_status == "+" then
      local _, _, reload_err = run_command("perpctl -L -b " .. perp_base .. " hup " .. service)
      if reload_err then
        print("Failed to reopen logs for " .. service .. "\n" .. reload_err)
        os.exit(1)
      end
    end
  end
end

local function reopen_nginx(perp_base)
  local _, _, err = run_command("perpctl -b " .. perp_base .. " 1 nginx")
  if err then
    print("Failed to reopen logs for nginx\n" .. err)
    os.exit(1)
  end
end

return function()
  local running = status()
  if not running then
    print("api-umbrella is stopped")
    os.exit(1)
  end

  local config = read_config()
  local perp_base = path.join(config["etc_dir"], "perp")

  reopen_perp_logs(perp_base)

  if config["_service_router_enabled?"] then
    reopen_nginx(perp_base)
  end
end
