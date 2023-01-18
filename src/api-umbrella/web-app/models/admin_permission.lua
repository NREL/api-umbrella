local json_null = require("cjson").null
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local time = require "api-umbrella.utils.time"

local AdminPermission = model_ext.new_class("admin_permissions", {
  as_json = function(self)
    return {
      id = json_null_default(self.id),
      name = json_null_default(self.name),
      display_order = json_null_default(self.display_order),
      created_at = json_null_default(time.postgres_to_iso8601(self.created_at)),
      created_by = json_null_default(self.created_by_id),
      updated_at = json_null_default(time.postgres_to_iso8601(self.updated_at)),
      updated_by = json_null_default(self.updated_by_id),
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
