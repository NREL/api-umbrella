local config = require "api-umbrella.proxy.models.file_config"
local path = require "pl.path"

auto_ssl = (require "resty.auto-ssl").new({
  dir = path.join(config["etc_dir"], "auto-ssl"),
  hook_server_port = config["auto_ssl"]["hook_server"]["port"],
  storage_adapter = "api-umbrella.auto-ssl.storage_adapters.mongodb",
})

auto_ssl:init()
