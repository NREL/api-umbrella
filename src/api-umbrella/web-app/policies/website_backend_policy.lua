local db = require "lapis.db"
local is_empty = require "api-umbrella.utils.is_empty"
local throw_authorization_error = require "api-umbrella.web-app.policies.throw_authorization_error"

local _M = {}

function _M.authorized_query_scope(current_admin, permission_id)
  assert(current_admin)

  if current_admin.superuser then
    return nil
  end

  if not permission_id then
    permission_id = "backend_manage"
  end

  local query_scopes = {}
  local api_scopes = current_admin:api_scopes_with_permission(permission_id)
  for _, api_scope in ipairs(api_scopes) do
    if api_scope:is_root() then
      table.insert(query_scopes, db.interpolate_query("website_backends.frontend_host = ?", api_scope.host))
    end
  end

  if is_empty(query_scopes) then
    -- Don't match any records if the admin has no authorized scopes.
    return "1 = 0"
  else
    return table.concat(query_scopes, " OR ")
  end
end

function _M.is_authorized_show(current_admin, data, permission_id)
  assert(current_admin)
  assert(data)

  if current_admin.superuser then
    return true
  end

  if not permission_id then
    permission_id = "backend_manage"
  end

  local any_scopes_allowed = false
  local api_scopes = current_admin:api_scopes_with_permission(permission_id)
  for _, api_scope in ipairs(api_scopes) do
    if data["frontend_host"] == api_scope.host and api_scope:is_root() then
      any_scopes_allowed = true
      break
    end
  end

  return any_scopes_allowed
end

function _M.authorize_show(current_admin, data, permission_id)
  local allowed = _M.is_authorized_show(current_admin, data, permission_id)
  if allowed then
    return true
  else
    return throw_authorization_error(current_admin)
  end
end

_M.authorize_modify = _M.authorize_show

return _M
