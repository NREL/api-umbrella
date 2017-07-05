local AdminPermission = require "api-umbrella.lapis.models.admin_permission"
local cjson = require "cjson"
local lapis_json = require "api-umbrella.utils.lapis_json"

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

  return lapis_json(self, response)
end

return function(app)
  app:get("/api-umbrella/v1/admin_permissions(.:format)", _M.index)
end
