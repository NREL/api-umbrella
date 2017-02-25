local run_command = require "api-umbrella.utils.run_command"
local status = require "api-umbrella.cli.status"
local time = require "posix.time"

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
  return stop_perp()
end
