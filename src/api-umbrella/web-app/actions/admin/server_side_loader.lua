local common_validations = require "api-umbrella.web-app.utils.common_validations"
local config = require("api-umbrella.utils.load_config")()
local json_encode = require "api-umbrella.utils.json_encode"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

local _M = {}

function _M.loader(self)
  local data
  local locale = ngx.ctx.locale
  if locale and LOCALE_DATA and LOCALE_DATA[locale] and LOCALE_DATA[locale]["locale_data"] then
    data = LOCALE_DATA[locale]["locale_data"]
  else
    data = {
      ["api-umbrella"] = {
        [""] = {
          domain = "api-umbrella",
          lang = "en",
          plural_forms = "nplurals=2; plural=(n != 1);",
        }
      }
    }
  end

  local web_config = {
    elasticsearch = {
      template_version = config["elasticsearch"]["template_version"],
    },
    web = {
      admin = {
        username_is_email = config["web"]["admin"]["username_is_email"],
      },
    },
  }

  self.res.headers["Content-Type"] = "application/javascript"
  self.res.content = [[
    window.apiUmbrellaConfig = ]] .. json_encode(web_config) .. [[;
    window.localeData = ]] .. json_encode(data) .. [[;
    window.CommonValidations = {
      host_format: new RegExp(]] .. json_encode(common_validations.host_format) .. [[),
      host_format_with_wildcard: new RegExp(]] .. json_encode(common_validations.host_format_with_wildcard) .. [[),
      url_prefix_format: new RegExp(]] .. json_encode(common_validations.url_prefix_format) .. [[)
    };
  ]]
  return { layout = false }
end

return function(app)
  app:match("/admin/server_side_loader.js", respond_to({ GET = _M.loader }))
end
