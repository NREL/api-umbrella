local json_response = require "api-umbrella.web-app.utils.json_response"

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
  app:get("/_web-app-state(.:format)", _M.state)
end
