local shell_blocking_capture_combined = require("shell-games").capture_combined

return function(path)
  local _, err = shell_blocking_capture_combined({ "mkdir", "-p", path })
  if err then
    return false, err
  end

  return true
end
