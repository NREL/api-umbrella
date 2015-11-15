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

function _M.reload()
  local reload = require "api-umbrella.cli.reload"
  reload()
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

function _M.ls()
  local ls = require "api-umbrella.cli.ls"
  ls()
end

function _M.health(args)
  local health = require "api-umbrella.cli.health"
  health(args)
end

function _M.version()
  local version = require "api-umbrella.version"
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

parser:command("start")
  :description("Start the API Umbrella server in the background.")

parser:command("stop")
  :description("Stop the API Umbrella server.")

parser:command("restart")
  :description("Restart the API Umbrella server.")

parser:command("reload")
  :description("Reload the configuration of the API Umbrella server.")

parser:command("status")
  :description("Show the status of the API Umbrella server.")

parser:command("reopen-logs")
  :description("Close and reopen log files in use.")

parser:command("ls")
  :description("List the processes running under API Umbrella.")

local health_command = parser:command("health")
  :description("Print the health of the API Umbrella services.")
health_command:option("--wait-for-status")
  :description("Wait for this health status (or better) to become true before returning")
health_command:option("--wait-timeout")
  :description("When --wait-for-status is being used, maximum time (in seconds) to wait before exiting")
  :default("50")
  :convert(tonumber)
  :show_default(true)

parser:command("version")
  :description("Print the API Umbrella version number.")

parser:command("help")
  :description("Show this help message and exit.")

return function()
  -- Parse the CLI options into a table.
  local args = parser:parse()

  -- Check which top-level command was given (start, stop, etc). There's no
  -- immediate way to tell this top-level command based on the args table, so
  -- check all the known commands to see which one was met.
  local command_found = false
  for command_name, command_function in pairs(_M) do
    command_name = string.gsub(command_name, "_", "-")
    if args[command_name] then
      command_function(args)
      command_found = true
      break
    end
  end

  -- If the function for the command wasn't found, print an error. This should
  -- not be expected, since argparse will exit earlier if the user passes in an
  -- unknown command. If we hit this, it indicates we have a documented command
  -- in argparse, but no corresponding function to call.
  if not command_found then
    print("Did not find function for command")
    os.exit(1)
  end
end
