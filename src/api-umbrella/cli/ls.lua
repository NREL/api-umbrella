local path = require "pl.path"
local read_config = require "api-umbrella.cli.read_config"
local status = require "api-umbrella.cli.status"
local unistd = require "posix.unistd"

local function list_processes(perp_base)
  local args = {
    "-b", perp_base,
  }

  unistd.execp("perpls", args)

  -- execp should replace the current process, so we've gotten this far it
  -- means execp failed, likely due to the "runtool" command not being found.
  print("Error: runtool command was not found")
  os.exit(1)
end

return function()
  local running = status()
  if not running then
    print("api-umbrella is stopped")
    os.exit(1)
  end

  local config = read_config()
  local perp_base = path.join(config["etc_dir"], "perp")
  list_processes(perp_base)
end
