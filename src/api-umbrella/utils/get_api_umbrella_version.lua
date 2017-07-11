local file = require "pl.file"
local path = require "pl.path"
local stringx = require "pl.stringx"

return function()
  local src_root_dir = os.getenv("API_UMBRELLA_SRC_ROOT")
  return stringx.strip(file.read(path.join(src_root_dir, "src/api-umbrella/version.txt")))
end
