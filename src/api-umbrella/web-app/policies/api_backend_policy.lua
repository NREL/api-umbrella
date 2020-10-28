local api_role_policy = require "api-umbrella.web-app.policies.api_role_policy"
local db = require "lapis.db"
local escape_db_like = require "api-umbrella.utils.escape_db_like"
local is_array = require "api-umbrella.utils.is_array"
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
    permission_id = "backend_manage"
  end

  local query_scopes = {}
  local api_scopes = current_admin:api_scopes_with_permission(permission_id)
  for _, api_scope in ipairs(api_scopes) do
    table.insert(query_scopes, db.interpolate_query("api_backends.frontend_host = ? AND api_backend_url_matches.frontend_prefix LIKE ? || '%'", api_scope.host, escape_db_like(api_scope.path_prefix)))
  end

  if is_empty(query_scopes) then
    -- Don't match any records if the admin has no authorized scopes.
    return "1 = 0"
  else
    -- Match API backends where the admin is authorized on *all* of its URL
    -- matches. This requires some subqueries, one to ensure we only match
    -- backends where URL matches exist, and another, using an anti-join, to
    -- filter out any backends that have any unauthorized url matches (which
    -- ensures we only match backends where *all* the url matches are
    -- authorized).
    return [[
      EXISTS (
        SELECT 1
        FROM api_backend_url_matches
        WHERE api_backends.id = api_backend_url_matches.api_backend_id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM api_backend_url_matches
        WHERE api_backends.id = api_backend_url_matches.api_backend_id
          AND (]] .. table.concat(query_scopes, " OR ") .. [[) IS NOT TRUE
      )
    ]]
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

  local url_matches = data["url_matches"]
  local all_url_matches_allowed = false
  if url_matches then
    local api_scopes = current_admin:api_scopes_with_permission(permission_id)
    for _, url_match in ipairs(url_matches) do
      local any_scopes_allowed = false
      for _, api_scope in ipairs(api_scopes) do
        if data["frontend_host"] == api_scope.host and startswith(url_match.frontend_prefix, api_scope.path_prefix) then
          any_scopes_allowed = true
          break
        end
      end

      if any_scopes_allowed then
        all_url_matches_allowed = true
      else
        all_url_matches_allowed = false
        break
      end
    end
  end

  return all_url_matches_allowed
end

function _M.authorize_show(current_admin, data, permission_id)
  local allowed = _M.is_authorized_show(current_admin, data, permission_id)
  if allowed then
    return true
  else
    return throw_authorization_error(current_admin)
  end
end

function _M.authorize_modify(current_admin, data, permission_id)
  if _M.authorize_show(current_admin, data, permission_id) then
    local roles = {}

    -- Collect all the roles from the backend settings.
    if data["settings"] and is_array(data["settings"]["required_role_ids"]) then
      for _, role in ipairs(data["settings"]["required_role_ids"]) do
        table.insert(roles, role)
      end
    end

    -- Collect all the roles from the sub-URL settings.
    if is_array(data["sub_settings"]) then
      for _, sub_settings in ipairs(data["sub_settings"]) do
        if sub_settings["settings"] and is_array(sub_settings["settings"]["required_role_ids"]) then
          for _, role in ipairs(sub_settings["settings"]["required_role_ids"]) do
            table.insert(roles, role)
          end
        end
      end
    end

    -- Verify that the admin is authorized for all of the roles being set.
    if api_role_policy.authorize_roles(current_admin, roles) then
      return true
    end
  end

  return throw_authorization_error(current_admin)
end

return _M
