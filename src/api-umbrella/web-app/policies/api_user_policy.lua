local api_role_policy = require "api-umbrella.web-app.policies.api_role_policy"
local db_null = require("lapis.db").NULL
local is_array = require "api-umbrella.utils.is_array"
local is_empty = require "api-umbrella.utils.is_empty"
local request_api_umbrella_roles = require "api-umbrella.utils.request_api_umbrella_roles"
local throw_authorization_error = require "api-umbrella.web-app.policies.throw_authorization_error"

local _M = {}

function _M.authorized_query_scope(current_admin)
  if not current_admin then
    return throw_authorization_error(current_admin)
  end

  if current_admin.superuser then
    return nil
  end

  local api_scopes = current_admin:api_scopes_with_permission("user_view")
  if is_empty(api_scopes) then
    -- Don't match any records if the admin has no authorized scopes.
    return "1 = 0"
  else
    return nil
  end
end

function _M.authorize_show(current_admin, data)
  if not current_admin then
    return throw_authorization_error(current_admin)
  end
  assert(data)

  if current_admin.superuser then
    return true
  end

  local api_scopes = current_admin:api_scopes_with_permission("user_view")
  if is_empty(api_scopes) then
    return throw_authorization_error(current_admin)
  else
    return true
  end
end

function _M.authorize_modify(current_admin, data)
  if not current_admin then
    return throw_authorization_error(current_admin)
  end
  assert(data)

  if current_admin.superuser then
    return true
  end

  local api_scopes = current_admin:api_scopes_with_permission("user_manage")
  if is_empty(api_scopes) then
    return throw_authorization_error(current_admin)
  end

  local role_ids = data["role_ids"]
  if is_array(role_ids) and role_ids ~= db_null then
    -- Verify that the admin is authorized for all of the roles being set.
    if not api_role_policy.authorize_roles(current_admin, data["role_ids"]) then
      return throw_authorization_error(current_admin)
    end
  end

  return true
end

function _M.authorize_create(current_admin, data)
  if not current_admin then
    local allowed = false

    -- To create users, don't require an admin user, so the signup form can be
    -- embedded on other sites. Instead, allow API keys with a
    -- "api-umbrella-key-creator" role to also create users.
    --
    -- This assumes API Umbrella is sitting in front and controlling access to
    -- this API with roles and other mechanisms (such as referer checking) to
    -- control signup access.
    local current_roles = request_api_umbrella_roles()
    if current_roles["api-umbrella-key-creator"] then
      allowed = true
    end

    if allowed then
      return true
    else
      return throw_authorization_error(current_admin)
    end
  else
    return _M.authorize_modify(current_admin, data)
  end
end

return _M
