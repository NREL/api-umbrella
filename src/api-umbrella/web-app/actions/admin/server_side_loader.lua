local common_validations = require "api-umbrella.web-app.utils.common_validations"
local file = require "pl.file"
local json_encode = require "api-umbrella.utils.json_encode"
local path = require "pl.path"

local _M = {}

-- local data = cjson.decode(file.read(path.join(config["_embedded_root_dir"], "apps/core/current/build/dist/locale/fr/LC_MESSAGES/api-umbrella.json")))
local data = {
  locale_data = {
    ["api-umbrella"] = {
      [""] = {
        domain = "api-umbrella",
        lang = "en_US",
      },
    },
  },
}

function _M.loader(self)
  self.res.headers["Content-Type"] = "text/javascript; charset=utf-8"
  self.res.headers["Cache-Control"] = "max-age=0, private, no-cache, no-store, must-revalidate"
  self.res.content = [[
    window.localeData = ]] .. json_encode(data["locale_data"]["api-umbrella"]) .. [[;
    window.CommonValidations = {
      host_format: new RegExp(]] .. json_encode(common_validations.host_format) .. [[),
      host_format_with_wildcard: new RegExp(]] .. json_encode(common_validations.host_format_with_wildcard) .. [[),
      url_prefix_format: new RegExp(]] .. json_encode(common_validations.url_prefix_format) .. [[)
    };
  ]]
  return { layout = false }
end

return function(app)
  app:get("/admin/server_side_loader.js", _M.loader)
end
