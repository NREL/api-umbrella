local lapis_config = require("lapis.config")

lapis_config("development", {
  postgres = {
    host = config["postgresql"]["host"],
    port = config["postgresql"]["port"],
    database = config["postgresql"]["database"],
    user = config["postgresql"]["username"],
    password = config["postgresql"]["password"],
  }
})
