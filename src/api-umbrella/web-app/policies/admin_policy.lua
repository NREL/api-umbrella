local AdminGroup = require "api-umbrella.web-app.models.admin_group"
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
    -- Match admin records where the current admin is authorized on *all* of
    -- its API scopes (via the admin groups). This requires some subqueries,
    -- one to ensure we only match admin records where admin groups and API
    -- scopes exist, and another, using an anti-join, to filter out any admin
    -- records that have any unauthorized API scopes (which ensures we only
    -- match admin records where *all* the API scopes are authorized).
    return db.interpolate_query([[
      EXISTS (
        SELECT 1
        FROM admin_groups_admins
          INNER JOIN admin_groups_api_scopes ON admin_groups_admins.admin_group_id = admin_groups_api_scopes.admin_group_id
        WHERE admins.id = admin_groups_admins.admin_id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM admin_groups_admins
          INNER JOIN admin_groups_api_scopes ON admin_groups_admins.admin_group_id = admin_groups_api_scopes.admin_group_id
        WHERE admins.id = admin_groups_admins.admin_id
          AND admin_groups_api_scopes.api_scope_id IN ? IS NOT TRUE
      )
    ]], db.list(api_scope_ids))
  end
end

function _M.is_authorized_modify(current_admin, data, permission_id)
  assert(current_admin)
  assert(data)

  if current_admin.superuser then
    return true
  end

  if data["superuser"] and data["superuser"] ~= false then
    return false
  end

  if not permission_id then
    permission_id = "admin_manage"
  end

  local all_groups_allowed = false
  if not is_empty(data["group_ids"]) then
    local authorized_api_scopes = invert_table(current_admin:nested_api_scope_ids_with_permission(permission_id))
    local api_scope_ids = AdminGroup.api_scope_ids_for_admin_group_ids(data["group_ids"])
    for _, api_scope_id in ipairs(api_scope_ids) do
      if authorized_api_scopes[api_scope_id] then
        all_groups_allowed = true
      else
        all_groups_allowed = false
        break
      end
    end
  end

  if all_groups_allowed then
    return true
  else
    return false
  end
end

function _M.authorize_modify(current_admin, data, permission_id)
  local allowed = _M.is_authorized_modify(current_admin, data, permission_id)
  if allowed then
    return true
  else
    return throw_authorization_error(current_admin)
  end
end

function _M.authorize_show(current_admin, data, permission_id)
  -- Allow admins to always view their own record, even if they don't have the
  -- admin_manage privilege (so they can view their admin token).
  --
  -- TODO: An admin should also be able to update their own password if using
  -- local password authentication, but that is not yet implemented.
  local allowed =  _M.is_authorized_modify(current_admin, data, permission_id) or (current_admin.id and data["id"] and current_admin.id == data["id"])
  if allowed then
    return true
  else
    return throw_authorization_error(current_admin)
  end
end

return _M
