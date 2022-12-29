local config = require("api-umbrella.utils.load_config")()

local app_env = config["app_env"]

local lapis_config = require("lapis.config")

-- Configuration based on the current environment (pulled from the global API
-- Umbrella config).
lapis_config(app_env, {
  postgres = {
    host = config["postgresql"]["host"],
    port = config["postgresql"]["port"],
    database = config["postgresql"]["database"],
    user = config["postgresql"]["username"],
    password = config["postgresql"]["password"],
    ssl = config["postgresql"]["ssl"],
    ssl_verify = config["postgresql"]["ssl_verify"],
    ssl_required = config["postgresql"]["ssl_required"],
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
