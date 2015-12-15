local file = require "pl.file"
local path = require "pl.path"
local read_config = require "api-umbrella.cli.read_config"
local run_command = require "api-umbrella.utils.run_command"
local stringx = require "pl.stringx"

-- Get the status of the legacy nodejs version (v0.8 and before) of the app.
--
-- This is present here so that we can cleanly perform package upgrades from
-- the legacy version and restart after the upgrade. At some point we can
-- probably remove this (once we no longer need to support upgrades from v0.8).
local function legacy_status()
  -- Only perform the legacy status if it appears as though it might be
  -- present.
  if not path.exists("/opt/api-umbrella/var/run/forever") then
    return nil
  end

  local _, output, err = run_command("pgrep -f '^/opt/api-umbrella/embedded/bin/node.*api-umbrella run'")
  if err and output ~= "" then
    return nil
  elseif err and output == "" then
    -- If the legacy process isn't running, then go ahead and remove the legacy
    -- directory so we know we don't need to do this again for an upgraded box.
    run_command("rm -rf /opt/api-umbrella/var/run/forever")
    return nil
  end

  local pid = tonumber(stringx.strip(output))
  return true, pid
end

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
    local status = run_command("runlock -c " .. pid_path)
    if status == 1 then
      running = true
    else
      pid = nil
    end
  end

  return running, pid
end

return function()
  local config = read_config()

  local legacy_running, legacy_pid = legacy_status()
  if legacy_running ~= nil then
    return legacy_running, legacy_pid
  end

  return perp_status(config)
end
