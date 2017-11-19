local json_null = require("cjson").null
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local time = require "api-umbrella.utils.time"

local AdminPermission = model_ext.new_class("admin_permissions", {
  as_json = function(self)
    return {
      id = self.id or json_null,
      name = self.name or json_null,
      display_order = self.display_order or json_null,
      created_at = time.postgres_to_iso8601(self.created_at) or json_null,
      created_by = self.created_by_id or json_null,
      updated_at = time.postgres_to_iso8601(self.updated_at) or json_null,
      updated_by = self.updated_by_id or json_null,
      deleted_at = json_null,
      version = 1,
    }
  end,
}, {
  authorize = function()
    return true
  end,
})

return AdminPermission
