local json_response = require "api-umbrella.web-app.utils.json_response"

local _M = {}

function _M.health(self)
  local response = {
    status = "green",
  }

  return json_response(self, response)
end

return function(app)
  app:get("/_web-app-health(.:format)", _M.health)
end
