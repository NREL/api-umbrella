-- Run a command line program and return its exit code and output.
return function(command)
  -- Since Lua 5.1 doesn't support getting the exit code and output
  -- simultaneously, this approach is a bit hacky. We redirect stderr to stdout
  -- (so our output includes everything), and then append the status code to
  -- the output and parse it out.
  --
  -- Based on this approach: http://lua-users.org/lists/lua-l/2009-06/msg00133.html
  --
  -- Revisit if LuaJIT get Lua 5.2 support since then pclose can provide the
  -- exit code.
  local handle = io.popen(command .. ' 2>&1; echo "===STATUS_CODE:$?"', "r")
  local all_output = handle:read("*all")
  handle:close()

  local output, status = string.match((all_output or ""), "^(.*)===STATUS_CODE:(%d+)\n$")
  local err = nil
  if output == nil and status == nil then
    -- This means we never got the "STATUS_CODE" output, so the entire
    -- sub-processes must have gotten killed off.
    err = "Executing command failed: " .. command .. "\n\nCommand exited prematurely. Was it killed by an external process?"
  else
    status = tonumber(status)
    if not status or status ~= 0 then
      err = "Executing command failed: " .. command .. "\n\n" .. output
    end
  end

  return status, output, err
end
