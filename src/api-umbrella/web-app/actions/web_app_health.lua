local json_response = require "api-umbrella.web-app.utils.json_response"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

local _M = {}

function _M.health(self)
  local response = {
    status = "green",
  }

  return json_response(self, response)
end

return function(app)
  app:match("/_web-app-health(.:format)", respond_to({ GET = _M.health }))
end
