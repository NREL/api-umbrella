local Model = require("lapis.db.model").Model
local cjson = require "cjson"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local function before_validate_on_create(_, values)
  values["sort_order"] = 0
end

local function validate(self, values)
  local errors = {}
  validate_field(errors, values, "name", validation.string:minlen(1), t("can't be blank"))
  return errors
end

local function before_save(self, values)
  if values["config"] then
    values["config"] = cjson.encode(values["config"])
  end
end

local save_options = {
  before_validate_on_create = before_validate_on_create,
  validate = validate,
  before_save = before_save,
}

local ApiBackend = Model:extend("api_backends", {
  update = model_ext.update(save_options),

  as_json = function(self)
    local data = {
      id = self.id or json_null,
      name = self.name or json_null,
      backend_protocol = self.config["backend_protocol"] or json_null,
      frontend_host = self.config["frontend_host"] or json_null,
      backend_host = self.config["backend_host"] or json_null,
      balance_algorithm = self.config["balance_algorithm"] or json_null,
      servers = self.config["servers"] or {},
      url_matches = self.config["url_matches"] or {},
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by or json_null,
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by or json_null,
      deleted_at = json_null,
      version = 1,
    }
    setmetatable(data["servers"], cjson.empty_array_mt)
    setmetatable(data["url_matches"], cjson.empty_array_mt)
    return data
  end,
})

ApiBackend.create = model_ext.create(save_options)

return ApiBackend
