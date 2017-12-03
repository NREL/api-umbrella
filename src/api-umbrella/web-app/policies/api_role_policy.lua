local invert_table = require "api-umbrella.utils.invert_table"
local startswith = require("pl.stringx").startswith
local throw_authorization_error = require "api-umbrella.web-app.policies.throw_authorization_error"

local _M = {}

local function is_authorized_role_id(role_id, disallowed_role_ids)
  if disallowed_role_ids[role_id] then
    return false
  elseif role_id ~= "api-umbrella-key-creator" and startswith(role_id, "api-umbrella") then
    return false
  end

  return true
end

function _M.authorized_index_roles(current_admin, role_ids)
  assert(current_admin)
  assert(role_ids)

  if current_admin.superuser then
    return role_ids
  end

  local authorized_role_ids = {}
  local disallowed_role_ids = invert_table(current_admin:disallowed_role_ids())
  for _, role_id in ipairs(role_ids) do
    if is_authorized_role_id(role_id, disallowed_role_ids) then
      table.insert(authorized_role_ids, role_id)
    end
  end

  return authorized_role_ids
end

function _M.authorize_roles(current_admin, role_ids)
  assert(current_admin)
  assert(role_ids)

  if current_admin.superuser then
    return true
  end

  local disallowed_role_ids = invert_table(current_admin:disallowed_role_ids())
  for _, role_id in ipairs(role_ids) do
    if not is_authorized_role_id(role_id, disallowed_role_ids) then
      return throw_authorization_error(current_admin)
    end
  end

  return true
end

return _M
