local inspect = require "inspect"

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

  local output, status = string.match(all_output, "^(.*)===STATUS_CODE:(%d+)\n$")
  status = tonumber(status)

  local err = nil
  if status ~= 0 then
    err = "Executing command failed: " .. command .. "\n\n" .. output
  end

  return status, output, err
end
