local config = require("api-umbrella.utils.load_config")()
local path_join = require "api-umbrella.utils.path_join"
local readfile = require("pl.utils").readfile
local stringx = require "pl.stringx"

return function()
  return stringx.strip(readfile(path_join(config["_src_root_dir"], "src/api-umbrella/version.txt")))
end
