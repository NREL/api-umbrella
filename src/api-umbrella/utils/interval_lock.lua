--- limit the execution of a function to once in a specific period of time.
-- A lock is held for the requested interval to prevent multiple worker
-- processes from executing the same fn
-- Example usage:
--    interval_lock('a-unique-name', 5.0, my_task)
--    calls my_task() once in a 5 second interval, regardless of workers
-- @param name a unique name for this lock
-- @param interval the length of time
-- @param fn the function to execute
-- @return ok, error
return function (name, interval, fn)
  local ok, err = ngx.shared.interval_locks:add(name, true, interval - 0.001)
  if not ok then
    if err == "exists" then
      return true, nil
    end
    return false, err
  end
  return pcall(fn)
end
