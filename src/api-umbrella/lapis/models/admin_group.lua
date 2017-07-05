local Model = require("lapis.db.model").Model
local validation = require "resty.validation"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local cjson = require "cjson"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local function validate(values)
  local errors = {}
  validate_field(errors, values, "name", validation.string:minlen(1), "can't be blank")
  return errors
end

local AdminGroup = Model:extend("admin_groups", {
  update = model_ext.update({ validate = validate }),

  as_json = function(self)
    return {
      id = self.id or json_null,
      name = self.name or json_null,
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by or json_null,
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by or json_null,
      deleted_at = json_null,
      version = 1,
    }
  end,
})

AdminGroup.create = model_ext.create({ validate = validate })

return AdminGroup
