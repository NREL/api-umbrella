local _M = {}

local ls = require "api-umbrella.cli.ls"
local reload = require "api-umbrella.cli.reload"
local reopen_logs = require "api-umbrella.cli.reopen_logs"
local run = require "api-umbrella.cli.run"
local status = require "api-umbrella.cli.status"
local stop = require "api-umbrella.cli.stop"
local version = require "api-umbrella.version"

function _M.run()
  run()
end

function _M.start()
  run({ background = true })
end

function _M.stop()
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
  reload()
end

function _M.status()
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
  reopen_logs()
end

function _M.ls()
  ls()
end

function _M.version()
  print(version)
end

function _M.help()
  print([[NAME
    api-umbrella - Open source API management

SYNOPSIS
    api-umbrella command

VERSION
    ]] .. version .. [[


COMMANDS
    run         - Run the API Umbrella server in the foreground
    start       - Start the API Umbrella server in the background
    stop        - Stop the API Umbrella server
    restart     - Restart the API Umbrella server
    reload      - Reload the configuration of the API Umbrella server
    status      - Show the status of the API Umbrella server
    reopen-logs - Close and reopen log files in use
    ls          - List the processes running under API Umbrella
    version     - Print the API Umbrella version number
    help        - Shows a list of commands or help for one command]])
end

return _M
