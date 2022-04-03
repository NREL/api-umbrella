local get_active_config = require("api-umbrella.web-app.stores.active_config_store").get
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local json_response = require "api-umbrella.web-app.utils.json_response"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

local _M = {}

function _M.state(self)
  local active_config = get_active_config()
  local response = {
    file_config_version = json_null_default(active_config["file_version"]),
    db_config_version = json_null_default(active_config["db_version"]),
  }

  return json_response(self, response)
end

return function(app)
  app:match("/_web-app-state(.:format)", respond_to({ GET = _M.state }))
end
