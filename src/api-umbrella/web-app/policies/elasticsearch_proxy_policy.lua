local throw_authorization_error = require "api-umbrella.web-app.policies.throw_authorization_error"

local _M = {}

function _M.authorize(current_admin)
  if current_admin and current_admin.superuser then
    return true
  end

  return throw_authorization_error(current_admin)
end

return _M
