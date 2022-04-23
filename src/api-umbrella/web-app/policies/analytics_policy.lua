local config = require("api-umbrella.utils.load_config")()
local is_empty = require "api-umbrella.utils.is_empty"
local request_api_umbrella_roles = require "api-umbrella.utils.request_api_umbrella_roles"
local throw_authorization_error = require "api-umbrella.web-app.policies.throw_authorization_error"

local _M = {}

function _M.authorized_query_scope(current_admin)
  assert(current_admin)

  if current_admin.superuser then
    return nil
  end

  local api_scopes = current_admin:api_scopes_with_permission("analytics")
  if is_empty(api_scopes) then
    -- Don't match any records if the admin has no authorized scopes.
    return {
      bool = {
        must_not = {
          match_all = {},
        },
      },
    }
  else
    local rules = {}
    for _, api_scope in ipairs(api_scopes) do
      table.insert(rules, {
        condition = "AND",
        rules = {
          {
            field = "request_host",
            operator = "equal",
            value = string.lower(api_scope.host),
          },
          {
            field = "request_path",
            operator = "begins_with",
            value = string.lower(api_scope.path_prefix),
          },
        },
      })
    end

    return {
      condition = "OR",
      rules = rules,
    }
  end
end

function _M.authorize_summary()
  local allowed = false

  local required_role = config["web"]["analytics_v0_summary_required_role"]
  if required_role == nil then
    allowed = true
  else
    local current_roles = request_api_umbrella_roles()
    if current_roles[required_role] then
      allowed = true
    end
  end

  if allowed then
    return true
  else
    return throw_authorization_error()
  end
end

return _M
