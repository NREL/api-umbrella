local config = require("api-umbrella.utils.load_config")()
local path_join = require "api-umbrella.utils.path_join"

auto_ssl = (require "resty.auto-ssl").new({
  dir = path_join(config["etc_dir"], "auto-ssl"),
  hook_server_port = config["auto_ssl"]["hook_server"]["port"],
  storage_adapter = "api-umbrella.auto-ssl.storage_adapters.postgresql",
})

auto_ssl:init()
