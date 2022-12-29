local generate_runtime_config = require "api-umbrella.utils.generate_runtime_config"
local json_decode = require("cjson").decode
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"
local path_exists = require "api-umbrella.utils.path_exists"
local readfile = require("pl.utils").readfile
local setenv = require("posix.stdlib").setenv

local local_config

local function load_config(options)
  local config
  local runtime_config_path = os.getenv("API_UMBRELLA_RUNTIME_CONFIG")
  if runtime_config_path and path_exists(runtime_config_path) then
    local content = readfile(runtime_config_path)
    config = json_decode(content)
    nillify_json_nulls(config)
  else
    config = generate_runtime_config(options)

    if options and options["persist_runtime_config"] then
      setenv("API_UMBRELLA_RUNTIME_CONFIG", config["_runtime_config_path"])
    end
  end

  -- Override Lapis' default environment to match API Umbrella's environment.
  --
  -- Note that this needs to be set early on, even before Lapis loads the
  -- src/config.lua file, since it loads the environment before that:
  -- https://github.com/leafo/lapis/blob/v1.9.0/lapis/config.lua#L130-L138
  --
  -- We also set this even when Lapis may not necessarily be loaded for
  -- simplicity sake so we can ensure any other commands (eg, cli commands like
  -- migrate) that get executed after loading our config are always in the
  -- right environment.
  local lapis_environment = os.getenv("LAPIS_ENVIRONMENT")
  if not lapis_environment then
    setenv("LAPIS_ENVIRONMENT", config["app_env"])
  end

  return config
end

return function(options)
  if not local_config then
    local_config = load_config(options)
  end

  return local_config
end
