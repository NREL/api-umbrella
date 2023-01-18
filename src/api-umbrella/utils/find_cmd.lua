local append_array = require "api-umbrella.utils.append_array"
local re_split = require("ngx.re").split
local shell_blocking_capture_combined = require("shell-games").capture_combined

return function(path, args)
  local find_args = {
    "find",
    path,
  }

  if args then
    append_array(find_args, args)
  end

  table.insert(find_args, "-print0")

  local find_result, find_err = shell_blocking_capture_combined(find_args)
  if find_err then
    return nil, find_err
  end

  local file_paths, split_err = re_split(find_result["output"], "\\0")
  if split_err then
    return nil, split_err
  end

  return file_paths
end
