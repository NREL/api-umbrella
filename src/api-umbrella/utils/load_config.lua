local generate_runtime_config = require "api-umbrella.utils.generate_runtime_config"
local json_decode = require("cjson").decode
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"
local path_exists = require "api-umbrella.utils.path_exists"
local readfile = require("pl.utils").readfile
local setenv = require("posix.stdlib").setenv

local local_config

local function load_config(options)
  local runtime_config_path = os.getenv("API_UMBRELLA_RUNTIME_CONFIG")
  if runtime_config_path and path_exists(runtime_config_path) then
    local content = readfile(runtime_config_path)
    local config = json_decode(content)
    nillify_json_nulls(config)
    return config
  else
    local config = generate_runtime_config(options)

    if options and options["persist_runtime_config"] then
      setenv("API_UMBRELLA_RUNTIME_CONFIG", config["_runtime_config_path"])
    end

    return config
  end
end

return function(options)
  if not local_config then
    local_config = load_config(options)
  end

  return local_config
end
