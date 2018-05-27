local path = require "pl.path"
local read_config = require "api-umbrella.cli.read_config"
local run_command = require "api-umbrella.utils.run_command"
local status = require "api-umbrella.cli.status"

local function reopen_perp_logs(parent_pid)
  -- Use pstree and parse the output to find all the log processes under the
  -- root process.
  --
  -- We use this instead of perpctl for finding the log processes, since
  -- perpctl doesn't seem to have a way to send signals to the root perpd's log
  -- process (just the services underneath perpd). Since we also want to be
  -- sure to reopen perpd's logs, we need to use this approach.
  local _, output, err = run_command({ "pstree", "-p", "-A", parent_pid })
  if err then
    print("Failed to reopen logs for perp\n" .. err)
    os.exit(1)
  end

  local log_process_name = "svlogd"
  for line in string.gmatch(output, "[^\r\n]+") do
    local log_pid = string.match(line, log_process_name .. "%((%d+)%)")
    if log_pid then
      local _, _, reload_err = run_command({ "kill", "-s", "HUP", log_pid })
      if reload_err then
        print("Failed to reopen logs for " .. log_pid .. "\n" .. reload_err)
        os.exit(1)
      end
    end
  end
end

local function reopen_nginx(perp_base)
  local _, _, err = run_command({ "perpctl", "-b", perp_base, "1", "nginx" })
  if err then
    print("Failed to reopen logs for nginx\n" .. err)
    os.exit(1)
  end
end

local function reopen_rsyslog(perp_base)
  local _, _, err = run_command({ "perpctl", "-b", perp_base, "hup", "rsyslog" })
  if err then
    print("Failed to reopen logs for rsyslog\n" .. err)
    os.exit(1)
  end
end

return function()
  local running, pid = status()
  if not running then
    print("api-umbrella is stopped")
    os.exit(1)
  end

  local config = read_config()
  local perp_base = path.join(config["etc_dir"], "perp")

  reopen_perp_logs(pid)

  if config["_service_router_enabled?"] then
    reopen_nginx(perp_base)
    reopen_rsyslog(perp_base)
  end
end
