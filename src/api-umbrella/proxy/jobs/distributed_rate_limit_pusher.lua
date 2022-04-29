local distributed_push = require("api-umbrella.proxy.stores.rate_limit_counters_store").distributed_push
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local delay = 0.25  -- in seconds
local new_timer = ngx.timer.at

local _M = {}

-- Repeat calls to distributed_push() inside each worker on the specified
-- interval (every 0.25 seconds).
--
-- We don't use interval_lock.repeat_with_mutex() here like most of our other
-- background jobs, because in this job's case we're pushing local worker data
-- into the database. In this case, we don't want a mutex across workers, since
-- we want each worker to operate independently and fire every 0.25 seconds to
-- push it's local data to the database. With a mutex, certain workers may not
-- be called for longer periods of time causing the local data to build up and
-- not be synced as frequently as we expect.
local function check(premature)
  if premature then
    return
  end

  local ok, err = xpcall(distributed_push, xpcall_error_handler)
  if not ok then
    ngx.log(ngx.ERR, "failed to run backend load cycle: ", err)
  end

  ok, err = new_timer(delay, check)
  if not ok then
    if err ~= "process exiting" then
      ngx.log(ngx.ERR, "failed to create timer: ", err)
    end

    return
  end
end

function _M.spawn()
  local ok, err = new_timer(0, check)
  if not ok then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
    return
  end
end

return _M
