local AdminPermission = require "api-umbrella.web-app.models.admin_permission"
local cjson = require "cjson"
local json_response = require "api-umbrella.web-app.utils.json_response"
local require_admin = require "api-umbrella.web-app.utils.require_admin"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

local _M = {}

function _M.index(self)
  local response = {
    admin_permissions = {}
  }

  local records = AdminPermission:select("ORDER BY display_order")
  for _, record in ipairs(records) do
    table.insert(response["admin_permissions"], record:as_json())
  end
  setmetatable(response["admin_permissions"], cjson.empty_array_mt)

  return json_response(self, response)
end

return function(app)
  app:match("/api-umbrella/v1/admin_permissions(.:format)", respond_to({ GET = require_admin(_M.index) }))
end
