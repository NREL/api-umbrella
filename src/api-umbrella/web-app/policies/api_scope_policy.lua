local db = require "lapis.db"
local is_empty = require "api-umbrella.utils.is_empty"
local startswith = require("pl.stringx").startswith
local throw_authorization_error = require "api-umbrella.web-app.policies.throw_authorization_error"

local _M = {}

function _M.authorized_query_scope(current_admin, permission_id)
  assert(current_admin)

  if current_admin.superuser then
    return nil
  end

  if not permission_id then
    permission_id = "admin_view"
  end

  local api_scope_ids = current_admin:nested_api_scope_ids_with_permission(permission_id)
  if is_empty(api_scope_ids) then
    -- Don't match any records if the admin has no authorized scopes.
    return "1 = 0"
  else
    -- Match all API scopes the admin is authorized to, or child scopes of
    -- those authorized scopes.
    --
    -- We defer this logic to the nested_api_scope_ids_with_permission method,
    -- and then just query based on the white-list of allowed IDs. This could
    -- probably be better abstracted or shifted into a single query.
    return db.interpolate_query("api_scopes.id IN ?", db.list(api_scope_ids))
  end
end

function _M.authorize_show(current_admin, data, permission_id)
  assert(current_admin)
  assert(data)

  if current_admin.superuser then
    return true
  end

  if not permission_id then
    permission_id = "admin_view"
  end

  local any_scopes_allowed = false
  local authorized_api_scopes = current_admin:api_scopes_with_permission(permission_id)
  for _, authorized_api_scope in ipairs(authorized_api_scopes) do
    if data["host"] == authorized_api_scope.host and data["path_prefix"] and startswith(data["path_prefix"], authorized_api_scope.path_prefix) then
      any_scopes_allowed = true
      break
    end
  end

  if any_scopes_allowed then
    return true
  else
    return throw_authorization_error(current_admin)
  end
end

function _M.authorize_modify(current_admin, data, permission_id)
  if not permission_id then
    permission_id = "admin_manage"
  end

  _M.authorize_show(current_admin, data, permission_id)
end

return _M
