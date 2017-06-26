local config = require("lapis.config")

config("development", {
  postgres = {
    host = "127.0.0.1",
    user = "vagrant",
    database = "api_umbrella_test"
  }
})
