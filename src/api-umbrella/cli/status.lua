local config = require("api-umbrella.utils.load_config")()
local path_exists = require "api-umbrella.utils.path_exists"
local path_join = require "api-umbrella.utils.path_join"
local readfile = require("pl.utils").readfile
local shell_blocking_capture_combined = require("shell-games").capture_combined

local function perp_status()
  local running = false
  local pid

  local pid_path = path_join(config["run_dir"], "perpboot.pid")
  if path_exists(pid_path) then
    pid = tonumber(readfile(pid_path))
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
  return perp_status()
end
