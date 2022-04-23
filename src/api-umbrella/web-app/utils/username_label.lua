local config = require("api-umbrella.utils.load_config")()
local t = require("api-umbrella.web-app.utils.gettext").gettext

return function()
  if config["web"]["admin"]["username_is_email"] then
    return t("Email")
  else
    return t("Username")
  end
end
