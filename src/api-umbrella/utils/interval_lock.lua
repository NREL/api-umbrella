local lock = require "resty.lock"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local _M = {}

--- Only one thread can execute fn through its execution duration
-- A lock (mutex) is held while the function executes and released at the end.
-- Logs errors; no return value
-- @param name - a unique identifier for this lock (automatically namespaced)
-- @param fn - function to execute if the lock can be held
_M.mutex_exec = function(name, fn)
  local check_lock, new_err = lock:new("locks", { timeout = 0 })
  if new_err then
    ngx.log(ngx.ERR, "failed to create lock (" .. (name or "") .. "): ", new_err)
    return
  end

  local _, lock_err = check_lock:lock("mutex_exec:" .. name)
  if lock_err then
    -- Since we don't wait to obtain a lock (timeout=0), timeout errors are
    -- expected, so don't log those (this should just mean that another worker
    -- is occupying this lock, so the work is being performed, just not by this
    -- worker).
    if lock_err ~= "timeout" then
      ngx.log(ngx.ERR, "failed to obtain lock (" .. (name or "") .. "): ", lock_err)
    end
    return
  end

  local pcall_ok, pcall_err = xpcall(fn, xpcall_error_handler)
  -- always attempt to unlock, even if the call failed
  local unlock_ok, unlock_err = check_lock:unlock()
  if not pcall_ok then
    ngx.log(ngx.ERR, "mutex exec pcall failed: ", pcall_err)
  end
  if not unlock_ok then
    ngx.log(ngx.ERR, "failed to unlock: ", unlock_err)
  end
end

--- Only allow a function to be executed once in a given interval
-- A lock (mutex) is set to expire after an interval of time. If the mutex is
-- present, execution won't take place. Logs errors, no return value
-- @param name - a unique identifier for this lock (automatically namespaced)
-- @param interval - the length of time until expiry (seconds)
-- @param fn - function to execute within the interval
_M.timeout_exec = function(name, interval, fn)
  local mem_ok, mem_err = ngx.shared.interval_locks:add(name, true, interval)
  if not mem_ok and mem_err ~= "exists" then
    ngx.log(ngx.ERR, "failed to allocate inverval_locks: ", mem_err)
  -- if not mem_ok and mem_err == "exists" is an acceptable scenario; it means
  -- that the mutex hasn't expired yet. NOOP in this situation
  elseif mem_ok then
    local pcall_ok, pcall_err = xpcall(fn, xpcall_error_handler)
    if not pcall_ok then
      ngx.log(ngx.ERR, "timeout exec pcall failed: ", pcall_err)
    end
  end
end

--- Call a function every `interval` amount of time
-- Set a timeout for next execution and run the provided function. Note that,
-- should the function execution take more time than the `interval`, this will
-- quickly backup. Combine with the mutexes above via `repeat_with_mutex`.
-- Logs errors, no return value
-- @param interval - the length of time until repeated (seconds)
-- @param fn - function to execute when the next timeout occurs
_M.repeat_exec = function(interval, fn)
  -- schedule the next call
  local ok, err = ngx.timer.at(interval, function(premature)
    if not premature then
      _M.repeat_exec(interval, fn)
    end
  end)
  if not ok and err ~= "process exiting" then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
  else
    -- execute fn now (may tie down this thread)
    local pcall_ok, pcall_err = xpcall(fn, xpcall_error_handler)
    if not pcall_ok then
      ngx.log(ngx.ERR, "repeat exec pcall failed: ", pcall_err)
    end
  end
end

--- Call a function once (or less) per time interval, across all threads
-- If execution takes longer than the interval to complete, execution of the
-- next cycle will start on the following expiry
-- @param name - a unique identifier for the relevant locks
-- @param interval - minimum time in between executions (seconds)
-- @param fn - function to execute
_M.repeat_with_mutex = function(name, interval, fn)
  -- Wrap the initial call in an immediate timer, so we know we're always
  -- executing fn() within the context of a timer (since some nginx APIs may
  -- not be available in other contexts, like init_worker_by_lua).
  local ok, err = ngx.timer.at(0, function(premature)
    if premature then
      return
    end

    _M.repeat_exec(interval, function()
      _M.mutex_exec(name, function()
        -- here we subtract the lock expiration time by 1ms to prevent
        -- a race condition with the next timer event.
        _M.timeout_exec(name, interval - 0.001, fn)
      end)
    end)
  end)
  if not ok and err ~= "process exiting" then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
  end
end

return _M
