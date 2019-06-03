local json_response = require "api-umbrella.web-app.utils.json_response"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

local _M = {}

function _M.state(self)
  local response = {
    file_config_version = ngx.shared.active_config:get("file_version"),
    db_config_version = ngx.shared.active_config:get("db_version"),
    db_config_last_fetched_at = ngx.shared.active_config:get("db_config_last_fetched_at"),
  }

  return json_response(self, response)
end

return function(app)
  app:match("/_web-app-state(.:format)", respond_to({ GET = _M.state }))
end
