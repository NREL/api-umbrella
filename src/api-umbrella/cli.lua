local _M = {}

local version = require "api-umbrella.version"
local run = require "api-umbrella.cli.run"
local reload = require "api-umbrella.cli.reload"

function _M.run()
  run()
end

function _M.start()
  run({ background = true })
end

function _M.stop()
end

function _M.restart()
end

function _M.reload()
  reload()
end

function _M.reopen_logs()
end

function _M.status()
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
    help        - Shows a list of commands or help for one command
    reload      - Reload the configuration of the API Umbrella server
    reopen_logs - Close and reopen log files in use
    restart     - Restart the API Umbrella server
    run         - Run the API Umbrella server in the foreground
    start       - Start the API Umbrella server
    status      - Show the status of the API Umbrella server
    stop        - Stop the API Umbrella server]])
end

return _M
