local file = require "pl.file"
local path = require "pl.path"
local read_config = require "api-umbrella.cli.read_config"
local shell_blocking_capture_combined = require("shell-games").capture_combined

local function perp_status(config)
  local running = false
  local pid

  local pid_path = path.join(config["run_dir"], "perpboot.pid")
  if(path.exists(pid_path)) then
    pid = tonumber(file.read(pid_path))
    if pid == 0 then
      pid = nil
    end
  end

  if pid then
    local result = shell_blocking_capture_combined({ "runlock", "-c", pid_path })
    if result["status"] == 1 then
      running = true
    else
      pid = nil
    end
  end

  return running, pid
end

return function()
  local config = read_config()
  return perp_status(config)
end
