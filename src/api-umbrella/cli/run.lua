local config = require("api-umbrella.utils.load_config")({ persist_runtime_config = true })
local path_join = require "api-umbrella.utils.path_join"
local setup = require "api-umbrella.cli.setup"
local status = require "api-umbrella.cli.status"
local unistd = require "posix.unistd"

local function start_perp(options)
  local running, _ = status()
  if running then
    print "api-umbrella is already running"
    if options and options["background"] then
      os.exit(0)
    else
      os.exit(1)
    end
  end

  local perp_base = path_join(config["etc_dir"], "perp")
  local args = {
    "-0", "api-umbrella",
    "-P", path_join(config["run_dir"], "perpboot.pid"),
  }

  -- If we want everything to stdout/stderr, then execute the lower-level perpd
  -- directly, so perpboot's own rc.log setup doesn't swallow all the logs
  -- (perpboot also requires rc.log to be setup, so we can't simply disable
  -- it).
  if config["log"]["destination"] == "console" then
    table.insert(args, "perpd")
  else
    table.insert(args, "perpboot")
  end

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
  setup()
  start_perp(options)
end
