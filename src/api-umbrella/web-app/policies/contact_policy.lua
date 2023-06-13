local request_api_umbrella_roles = require "api-umbrella.utils.request_api_umbrella_roles"
local throw_authorization_error = require "api-umbrella.web-app.policies.throw_authorization_error"

local _M = {}

function _M.authorize_create()
  local allowed = false

  local current_roles = request_api_umbrella_roles(ngx.ctx)
  if current_roles["api-umbrella-contact-form"] then
    allowed = true
  end

  if allowed then
    return true
  else
    return throw_authorization_error()
  end
end

return _M
