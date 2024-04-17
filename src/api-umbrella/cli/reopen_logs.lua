local config = require("api-umbrella.utils.load_config")()
local path_join = require "api-umbrella.utils.path_join"
local shell_blocking_capture_combined = require("shell-games").capture_combined
local status = require "api-umbrella.cli.status"

local function reopen_perp_logs(parent_pid)
  -- Use pstree and parse the output to find all the log processes under the
  -- root process.
  --
  -- We use this instead of perpctl for finding the log processes, since
  -- perpctl doesn't seem to have a way to send signals to the root perpd's log
  -- process (just the services underneath perpd). Since we also want to be
  -- sure to reopen perpd's logs, we need to use this approach.
  local result, err = shell_blocking_capture_combined({ "pstree", "-p", "-A", parent_pid })
  if err then
    print("Failed to reopen logs for perp\n" .. err)
    os.exit(1)
  end

  local log_process_name = "svlogd"
  for line in string.gmatch(result["output"], "[^\r\n]+") do
    local log_pid = string.match(line, log_process_name .. "%((%d+)%)")
    if log_pid then
      local _, reload_err = shell_blocking_capture_combined({ "kill", "-s", "HUP", log_pid })
      if reload_err then
        print("Failed to reopen logs for " .. log_pid .. "\n" .. reload_err)
        os.exit(1)
      end
    end
  end
end

local function reopen_nginx(perp_base)
  local _, err = shell_blocking_capture_combined({ "perpctl", "-b", perp_base, "1", "nginx" })
  if err then
    print("Failed to reopen logs for nginx\n" .. err)
    os.exit(1)
  end
end

return function()
  local running, pid = status()
  if not running then
    print("api-umbrella is stopped")
    os.exit(1)
  end

  local perp_base = path_join(config["etc_dir"], "perp")

  reopen_perp_logs(pid)

  if config["_service_router_enabled?"] then
    reopen_nginx(perp_base)
  end
end
