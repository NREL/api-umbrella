local ApiUser = require "api-umbrella.web-app.models.api_user"
local capture_errors_json_full = require("api-umbrella.web-app.utils.capture_errors").json_full
local hmac = require "api-umbrella.utils.hmac"
local json_response = require "api-umbrella.web-app.utils.json_response"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

local _M = {}

function _M.validate(self)
  local response = {
    status = "invalid",
  }

  local api_key_hash = hmac(self.params["api_key"])
  local api_user = ApiUser:find({ api_key_hash = api_key_hash })
  if api_user then
    response["status"] = "valid"
  end

  return json_response(self, response)
end

return function(app)
  app:match("/api-umbrella/api-users/:api_key/validate(.:format)", respond_to({ GET = capture_errors_json_full(_M.validate) }))
end
