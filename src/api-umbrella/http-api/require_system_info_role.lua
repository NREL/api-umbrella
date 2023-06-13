local json_encode = require "api-umbrella.utils.json_encode"
local request_api_umbrella_roles = require "api-umbrella.utils.request_api_umbrella_roles"

local required_role = "api-umbrella-system-info"
local current_roles = request_api_umbrella_roles(ngx.ctx)
if not current_roles[required_role] then
  ngx.status = 403
  ngx.header["Content-Type"] = "application/json"
  ngx.say(json_encode({
    errors = {
      {
        code = "API_KEY_UNAUTHORIZED",
        message = "The api_key supplied is not authorized to access the given service.",
      },
    },
  }))
  return ngx.exit(ngx.HTTP_OK)
end
