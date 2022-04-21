local path_join = require "api-umbrella.utils.path_join"
local readfile = require("pl.utils").readfile
local stringx = require "pl.stringx"

return function()
  local src_root_dir = os.getenv("API_UMBRELLA_SRC_ROOT")
  return stringx.strip(readfile(path_join(src_root_dir, "src/api-umbrella/version.txt")))
end
