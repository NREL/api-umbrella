local ApiRole = require "api-umbrella.web-app.models.api_role"
local api_role_policy = require "api-umbrella.web-app.policies.api_role_policy"
local cjson = require "cjson"
local json_response = require "api-umbrella.web-app.utils.json_response"
local require_admin = require "api-umbrella.web-app.utils.require_admin"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

local _M = {}

function _M.index(self)
  local role_ids = ApiRole:all_ids()
  local authorized_role_ids = api_role_policy.authorized_index_roles(self.current_admin, role_ids)

  local roles = {}
  for _, role_id in ipairs(authorized_role_ids) do
    table.insert(roles, {
      id = role_id,
    })
  end

  local response = {
    user_roles = roles,
  }
  setmetatable(response["user_roles"], cjson.empty_array_mt)

  return json_response(self, response)
end

return function(app)
  app:match("/api-umbrella/v1/user_roles(.:format)", respond_to({ GET = require_admin(_M.index) }))
end
