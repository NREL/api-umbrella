local lapis_config = require("lapis.config")

-- Configuration based on the current environment (pulled from the global API
-- Umbrella config).
lapis_config(config["app_env"], {
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
