local db = require "lapis.db"
local is_empty = require("pl.types").is_empty
local escape_db_like = require "api-umbrella.utils.escape_db_like"
local yield_error = require("lapis.application").yield_error
local t = require("resty.gettext").gettext
local startswith = require("pl.stringx").startswith

local _M = {}

function _M.scope(current_admin, permission_id)
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

function _M.authorize_record(current_admin, data, permission_id)
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

  if all_url_matches_allowed then
    return true
  else
    local authorized_scopes_list = {}
    local api_scopes = current_admin:api_scopes()
    for _, api_scope in ipairs(api_scopes) do
      table.insert(authorized_scopes_list, "- " .. (api_scope.host or "") .. (api_scope.path_prefix or ""))
    end
    table.sort(authorized_scopes_list)

    coroutine.yield("error", {
      {
        code = "FORBIDDEN",
        message = string.format(t("You are not authorized to perform this action. You are only authorized to perform actions for APIs in the following areas:\n\n%s\n\nContact your API Umbrella administrator if you need access to new APIs."), table.concat(authorized_scopes_list, "\n")),
      }
    })
    return false
  end
end

return _M
