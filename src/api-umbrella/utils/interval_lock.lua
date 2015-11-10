local lock = require "resty.lock"

local _M = {}

--- Only one thread can execute fn through its execution duration
-- A lock (mutex) is held while the function executes and released at the end
-- @param name - a unique identifier for this lock (automatically namespaced)
-- @param fn - function to execute if the lock can be held
-- @return ok, error
_M.mutex_exec = function(name, fn)
  local check_lock = lock:new("locks", {["timeout"] = 0})
  local _, lock_err = check_lock:lock("mutex_exec:" .. name)
  if lock_err then
    return true, nil
  else
    local results = pcall(fn)
    local ok, unlock_err = check_lock:unlock()
    if not ok then
      ngx.log(ngx.ERR, "failed to unlock: ", unlock_err)
    end
    return results
  end
end

--- Only allow a function to be executed once in a given interval
-- A lock (mutex) is set to expire after an interval of time. If the mutex is
-- present, execution won't take place
-- @param name - a unique identifier for this lock (automatically namespaced)
-- @param interval - the length of time until expiry (seconds)
-- @param fn - function to execute within the interval
-- @return ok, error
_M.timeout_exec = function(name, interval, fn)
  local ok, err = ngx.shared.interval_locks:add(name, true, interval)
  if not ok and err == "exists" then
    return true, nil
  elseif not ok then
    return false, err
  else
    return pcall(fn)
  end
end

--- Call a function every `interval` amount of time
-- Set a timeout for next execution and run the provided function. Note that,
-- should the function execution take more time than the `interval`, this will
-- quickly backup. Combine with the mutexes above via `repeat_with_mutex`
-- @param interval - the length of time until repeated (seconds)
-- @param fn - function to execute when the next timeout occurs
_M.repeat_exec = function(interval, fn)
  -- schedule the next call
  local ok, err = ngx.timer.at(interval, function()
    _M.repeat_exec(interval, fn)
  end)
  if not ok and err ~= "process exiting" then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
  else
    -- execute fn now (may tie down this thread)
    pcall(fn)
  end
end

--- Call a function once (or less) per time interval, across all threads
-- If execution takes longer than the interval to complete, execution of the
-- next cycle will start on the following expiry
-- @param name - a unique identifier for the relevant locks
-- @param interval - minimum time in between executions (seconds)
-- @param fn - function to execute
_M.repeat_with_mutex = function(name, interval, fn)
  _M.repeat_exec(interval, function()
    return _M.mutex_exec(name, function()
      -- here we subtract the lock expiration time by 1ms to prevent
      -- a race condition with the next timer event.
      return _M.timeout_exec(name, interval - 0.001, fn)
    end)
  end)
end

return _M
