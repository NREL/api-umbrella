local config = require "api-umbrella.proxy.models.file_config"
local lapis_config = require("lapis.config")
local util = require("lapis.cmd.util")

local app_env = config["app_env"]

-- Override Lapis' default environment to match API Umbrella's environment.
util.default_environment = function()
  return app_env
end

-- Configuration based on the current environment (pulled from the global API
-- Umbrella config).
lapis_config(app_env, {
  postgres = {
    host = config["postgresql"]["host"],
    port = config["postgresql"]["port"],
    database = config["postgresql"]["database"],
    user = config["postgresql"]["username"],
    password = config["postgresql"]["password"],
  },

  -- Increase number of parsed POST arguments, for compatibility with some of
  -- the datatables APIs (which have a lot of separate arguments).
  max_request_args = 500,

  -- Use the API Umbrella secret key for Lapis's secret setup too.
  secret = assert(config["secret_key"]),
})

-- Environment specific configuration.
lapis_config("development", {
  show_errors = true,
})
