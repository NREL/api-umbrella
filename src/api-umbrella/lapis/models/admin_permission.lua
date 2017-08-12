local iso8601 = require "api-umbrella.utils.iso8601"
local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"

local AdminPermission = model_ext.new_class("admin_permissions", {
  as_json = function(self)
    return {
      id = self.id or json_null,
      name = self.name or json_null,
      display_order = self.display_order or json_null,
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by or json_null,
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by or json_null,
      deleted_at = json_null,
      version = 1,
    }
  end,
})

return AdminPermission
