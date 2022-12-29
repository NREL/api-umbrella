local stat = require("posix.sys.stat").stat

return function(path)
  local path_stat = stat(path)
  return path_stat ~= nil
end
