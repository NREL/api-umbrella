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
  }
})

-- Environment specific configuration.
lapis_config("development", {
  show_errors = true,
})
