local cjson = require "cjson"
local file = require "pl.file"
local path = require "pl.path"

local _M = {}

local data = cjson.decode(file.read(path.join(config["_embedded_root_dir"], "apps/core/current/build/dist/locale/fr/LC_MESSAGES/api-umbrella.json")))

function _M.loader(self)
  self.res.headers["Content-Type"] = "text/javascript; charset=utf-8"
  self.res.headers["Cache-Control"] = "max-age=0, private, no-cache, no-store, must-revalidate"
  self.res.content = [[
    window.localeData = ]] .. cjson.encode(data["locale_data"]["api-umbrella"]) .. [[;
    window.CommonValidations = {
    };
  ]]
  return { layout = false }
end

return function(app)
  app:get("/admin/server_side_loader.js", _M.loader)
end
