local argparse = require "argparse"

local parser = argparse("api-umbrella", "Open source API management")

local _M = {}
function _M.run()
  local run = require "api-umbrella.cli.run"
  run()
end

function _M.start()
  local run = require "api-umbrella.cli.run"
  run({ background = true })
end

function _M.stop()
  local stop = require "api-umbrella.cli.stop"
  local ok, err = stop()
  if not ok then
    print(err)
    os.exit(1)
  end
end

function _M.restart()
  _M.stop()
  _M.start()
end

function _M.reload(args)
  local reload = require "api-umbrella.cli.reload"
  reload(args)
end

function _M.status()
  local status = require "api-umbrella.cli.status"
  local running, pid = status()
  if running then
    print("api-umbrella (pid " .. (pid or "") .. ") is running...")
    os.exit(0)
  else
    print("api-umbrella is stopped")
    os.exit(3)
  end
end

function _M.reopen_logs()
  local reopen_logs = require "api-umbrella.cli.reopen_logs"
  reopen_logs()
end

function _M.processes()
  local processes = require "api-umbrella.cli.processes"
  processes()
end

function _M.health(args)
  local health = require "api-umbrella.cli.health"
  health(args)
end

function _M.version()
  local file = require "pl.file"
  local path = require "pl.path"
  local stringx = require "pl.stringx"
  local src_root_dir = os.getenv("API_UMBRELLA_SRC_ROOT")
  local version = stringx.strip(file.read(path.join(src_root_dir, "src/api-umbrella/version.txt")))
  print(version)
  os.exit(0)
end

function _M.help()
  print(parser:get_help())
end

parser:flag("--version")
  :description("Print the API Umbrella version number.")
  :action(_M.version)

parser:command("run")
  :description("Run the API Umbrella server in the foreground.")
  :action(_M.run)

parser:command("start")
  :description("Start the API Umbrella server in the background.")
  :action(_M.start)

parser:command("stop")
  :description("Stop the API Umbrella server.")
  :action(_M.stop)

parser:command("restart")
  :description("Restart the API Umbrella server.")
  :action(_M.restart)

local reload_command = parser:command("reload")
  :description("Reload the configuration of the API Umbrella server.")
  :action(_M.reload)
reload_command:flag("--router")
  :description("Reload only the router processes")
reload_command:flag("--web")
  :description("Reload only the web processes")

parser:command("status")
  :description("Show the status of the API Umbrella server.")
  :action(_M.status)

parser:command("reopen-logs")
  :description("Close and reopen log files in use.")
  :action(_M.reopen_logs)

parser:command("processes")
  :description("List the status of the processes running under API Umbrella.")
  :action(_M.processes)

local health_command = parser:command("health")
  :description("Print the health of the API Umbrella services.")
  :action(_M.health)
health_command:option("--wait-for-status")
  :description("Wait for this health status (or better) to become true before returning")
health_command:option("--wait-timeout")
  :description("When --wait-for-status is being used, maximum time (in seconds) to wait before exiting")
  :default("50")
  :convert(tonumber)
  :show_default(true)

parser:command("version")
  :description("Print the API Umbrella version number.")
  :action(_M.version)

parser:command("help")
  :description("Show this help message and exit.")
  :action(_M.help)

return function()
  parser:parse()
end
