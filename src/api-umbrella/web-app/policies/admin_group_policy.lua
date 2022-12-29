local db = require "lapis.db"
local invert_table = require "api-umbrella.utils.invert_table"
local is_empty = require "api-umbrella.utils.is_empty"
local throw_authorization_error = require "api-umbrella.web-app.policies.throw_authorization_error"

local _M = {}

function _M.authorized_query_scope(current_admin, permission_id)
  assert(current_admin)

  if current_admin.superuser then
    return nil
  end

  if not permission_id then
    permission_id = "admin_manage"
  end

  local api_scope_ids = current_admin:nested_api_scope_ids_with_permission(permission_id)
  if is_empty(api_scope_ids) then
    -- Don't match any records if the admin has no authorized scopes.
    return "1 = 0"
  else
    -- Match admin groups where the admin is authorized on *all* of its API
    -- scopes. This requires some subqueries, one to ensure we only match admin
    -- groups where API scopes exist, and another, using an anti-join, to
    -- filter out any admin groups that have any unauthorized API scopes (which
    -- ensures we only match admin groups where *all* the API scopes are
    -- authorized).
    return db.interpolate_query([[
      EXISTS (
        SELECT 1
        FROM admin_groups_api_scopes
        WHERE admin_groups.id = admin_groups_api_scopes.admin_group_id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM admin_groups_api_scopes
        WHERE admin_groups.id = admin_groups_api_scopes.admin_group_id
          AND admin_groups_api_scopes.api_scope_id IN ? IS NOT TRUE
      )
    ]], db.list(api_scope_ids))
  end
end

function _M.authorize_show(current_admin, data, permission_id)
  assert(current_admin)
  assert(data)

  if current_admin.superuser then
    return true
  end

  if not permission_id then
    permission_id = "admin_manage"
  end

  local all_scopes_allowed = false
  if not is_empty(data["api_scope_ids"]) then
    local authorized_api_scopes = invert_table(current_admin:nested_api_scope_ids_with_permission(permission_id))
    for _, api_scope_id in ipairs(data["api_scope_ids"]) do
      if authorized_api_scopes[api_scope_id] then
        all_scopes_allowed = true
      else
        all_scopes_allowed = false
        break
      end
    end
  end

  if all_scopes_allowed then
    return true
  else
    return throw_authorization_error(current_admin)
  end
end

_M.authorize_modify = _M.authorize_show

return _M
