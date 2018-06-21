config = require "api-umbrella.proxy.models.file_config"

auto_ssl = (require "resty.auto-ssl").new({
  hook_server_port = config["auto_ssl"]["hook_server"]["port"]
})

auto_ssl:init()
