local config = require("api-umbrella.utils.load_config")()
local mail = require "resty.mail"

return function()
  return mail.new({
    host = config["web"]["mailer"]["smtp_settings"]["address"],
    port = config["web"]["mailer"]["smtp_settings"]["port"],
    username = config["web"]["mailer"]["smtp_settings"]["user_name"],
    password = config["web"]["mailer"]["smtp_settings"]["password"],
    auth_type = config["web"]["mailer"]["smtp_settings"]["authentication"],
    domain = config["web"]["mailer"]["smtp_settings"]["domain"],
    starttls = config["web"]["mailer"]["smtp_settings"]["starttls"],
    ssl = config["web"]["mailer"]["smtp_settings"]["ssl"],
    ssl_verify = config["web"]["mailer"]["smtp_settings"]["ssl_verify"],
    ssl_host = config["web"]["mailer"]["smtp_settings"]["ssl_host"],
  })
end
