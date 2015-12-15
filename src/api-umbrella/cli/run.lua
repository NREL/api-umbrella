local path = require "pl.path"
local setup = require "api-umbrella.cli.setup"
local status = require "api-umbrella.cli.status"
local unistd = require "posix.unistd"

local function start_perp(config, options)
  local running, _ = status()
  if running then
    print "api-umbrella is already running"
    if options and options["background"] then
      os.exit(0)
    else
      os.exit(1)
    end
  end

  local perp_base = path.join(config["etc_dir"], "perp")
  local args = {
    "-0", "api-umbrella",
    "-P", path.join(config["run_dir"], "perpboot.pid"),
    "perpboot",
  }

  if options and options["background"] then
    table.insert(args, 1, "-d")
  end

  table.insert(args, perp_base)

  unistd.execp("runtool", args)

  -- execp should replace the current process, so we've gotten this far it
  -- means execp failed, likely due to the "runtool" command not being found.
  print("Error: runtool command was not found")
  os.exit(1)
end

return function(options)
  local config = setup()
  start_perp(config, options)
end
