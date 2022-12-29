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
    ssl = config["web"]["mailer"]["smtp_settings"]["ssl"],
  })
end
