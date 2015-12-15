local path = require "pl.path"
local run_command = require "api-umbrella.utils.run_command"
local status = require "api-umbrella.cli.status"
local stringx = require "pl.stringx"
local time = require "posix.time"

-- Stop the legacy nodejs version (v0.8 and before) of the app.
--
-- This is present here so that we can cleanly perform package upgrades from
-- the legacy version and restart after the upgrade. At some point we can
-- probably remove this (once we no longer need to support upgrades from v0.8).
local function stop_legacy()
  -- Only perform the legacy stop if it appears as though it might be present.
  if not path.exists("/opt/api-umbrella/var/run/forever") then
    return true
  end

  local running, _ = status()
  if not running then
    print "api-umbrella is already stopped"
    return true
  end

  -- Stop the various processes tied to the old service.
  local _, output, err = run_command("pkill -TERM -f '^/opt/api-umbrella/embedded/bin/node.*forever/bin/monitor.*api-umbrella'")
  if err and output ~= "" then
    return false, err
  end

  _, output, err = run_command("pkill -TERM -f '^/opt/api-umbrella/embedded/bin/node.*api-umbrella run'")
  if err and output ~= "" then
    return false, err
  end

  _, output, err = run_command("pgrep -f '^/opt/api-umbrella/embedded/bin/python.*supervisord.*api-umbrella'")
  if err and output ~= "" then
    return false, err
  elseif err and output == "" then
    return true
  end

  local supervisord_pid = stringx.strip(output)
  _, _, err = run_command("kill -s TERM " .. supervisord_pid)
  if err then
    return false, err
  end

  -- Wait until the old processes have completely shut down.
  local stopped = false
  for _ = 1, 200 do
    local supervisord_status = run_command("pgrep -f '/opt/api-umbrella/embedded/bin/python.*supervisord.*api-umbrella'")
    if supervisord_status == 0 then
      -- Sleep for 0.2 seconds.
      time.nanosleep({ tv_sec = 0, tv_nsec = 200000000 })
    else
      stopped = true
      break
    end
  end

  if not stopped then
    return false, "failed to stop"
  end

  -- Remove the legacy directory so we know we don't need to do this again for
  -- an upgraded box.
  _, _, err = run_command("rm -rf /opt/api-umbrella/var/run/forever")
  if err then
    return false, err
  end

  return true
end

local function stop_perp()
  local running, pid = status()
  if not running then
    print "api-umbrella is already stopped"
    return true
  end

  local _, _, err = run_command("kill -s TERM " .. pid)
  if err then
    return false, err
  end

  -- After sending the kill command, wait for everything to actually
  -- shutdown. This allows us to more easily handle restarts (since we can
  -- ensure everything is stopped before calling start).
  --
  -- Wait up to 40 seconds.
  local stopped = false
  for _ = 1, 200 do
    running, _ = status()
    if running then
      -- Sleep for 0.2 seconds.
      time.nanosleep({ tv_sec = 0, tv_nsec = 200000000 })
    else
      stopped = true
      break
    end
  end

  if not stopped then
    return false, "failed to stop"
  end

  return true
end

return function()
  local ok, err = stop_legacy()
  if not ok then
    return ok, err
  end

  return stop_perp()
end
