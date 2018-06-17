-- Shell escaping based on Ruby's Shellwords:
-- https://github.com/ruby/ruby/blob/trunk/lib/shellwords.rb
local function shellescape(str)
  str = tostring(str)

  -- Return empty quotes for empty value.
  if not str or #str == 0 then
    return "''"
  end

  local escaped_str, _, gsub_err = ngx.re.gsub(str, [[([^A-Za-z0-9_\-.,:\/@\n])]], [[\$1]], "jo")
  if gsub_err then
    ngx.log(ngx.ERR, "regex error: ", gsub_err)
    return nil
  end

  escaped_str, _, gsub_err = ngx.re.gsub(escaped_str, [[\n]], "'\n'", "jo")
  if gsub_err then
    ngx.log(ngx.ERR, "regex error: ", gsub_err)
    return nil
  end

  return escaped_str
end
local function shelljoin(array)
  local escaped = {}
  for _, str in ipairs(array) do
    table.insert(escaped, shellescape(str))
  end

  return table.concat(escaped, " ")
end

-- Run a command line program and return its exit code and output.
return function(args)
  -- Turn table of command arguments into a single command string, escaping as
  -- appropriate.
  local command = shelljoin(args)

  -- We don't have a clean way to get the exit code from close() when executing
  -- via the resty cli
  -- (https://github.com/openresty/lua-nginx-module/issues/779). This approach
  -- is a bit hacky. We redirect stderr to stdout (so our output includes
  -- everything), and then append the status code to the output and parse it
  -- out.
  --
  -- Based on this approach: http://lua-users.org/lists/lua-l/2009-06/msg00133.html
  local handle = io.popen(command .. ' 2>&1; echo "===STATUS_CODE:$?"', "r")
  local all_output = handle:read("*all")
  handle:close()

  local status, output, err

  local matches, match_err = ngx.re.match(all_output, [[^(.*)===STATUS_CODE:(\d+)$]], "jos")
  if matches then
    output = matches[1]
    status = matches[2]
  elseif match_err then
    err = "Executing command failed: " .. command .. "\n\nRegex error: " .. match_err
  end

  if not err then
    if status == nil then
      -- This means we never got the "STATUS_CODE" output, so the entire
      -- sub-processes must have gotten killed off.
      err = "Executing command failed: " .. command .. "\n\nCommand exited prematurely. Was it killed by an external process?"
    else
      status = tonumber(status)
      if not status or status ~= 0 then
        err = "Executing command failed: " .. command .. "\n\n" .. output
      end
    end
  end

  return status, output, err
end
