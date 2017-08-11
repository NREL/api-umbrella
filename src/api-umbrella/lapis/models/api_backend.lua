local Model = require("lapis.db.model").Model
local cjson = require "cjson"
local is_array = require "api-umbrella.utils.is_array"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local uuid_generate = require("resty.uuid").generate_random
local validation = require "resty.validation"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local function before_validate_on_create(_, values)
  values["sort_order"] = 0

  if is_array(values["servers"]) then
    for _, server in ipairs(values["servers"]) do
      server["id"] = uuid_generate()
    end
  end

  if is_array(values["url_matches"]) then
    for _, url_match in ipairs(values["url_matches"]) do
      url_match["id"] = uuid_generate()
    end
  end
end

local function validate(self, values)
  ngx.log(ngx.ERR, "VALUES: " .. inspect(values))
  local errors = {}
  validate_field(errors, values, "name", validation.string:minlen(1), t("can't be blank"))
  validate_field(errors, values, "sort_order", validation.number, t("can't be blank"))

  validate_field(errors, values, "servers", validation.table:minlen(1), t("can't be blank"))
  if values["servers"] then
    for index, server in ipairs(values["servers"]) do
      local error_field_prefix = "servers." .. index .. "."
      validate_field(errors, server, "id", validation.string:minlen(1), t("can't be blank"), error_field_prefix)
      validate_field(errors, server, "host", validation.string:minlen(1), t("can't be blank"), error_field_prefix)
      validate_field(errors, server, "port", validation.number:between(0, 65535), t("can't be blank"), error_field_prefix)
    end
  end

  validate_field(errors, values, "url_matches", validation.table:minlen(1), t("can't be blank"))
  if values["url_matches"] then
    for index, url_match in ipairs(values["url_matches"]) do
      local error_field_prefix = "url_matches." .. index .. "."
      validate_field(errors, url_match, "id", validation.string:minlen(1), t("can't be blank"), error_field_prefix)
      validate_field(errors, url_match, "frontend_prefix", validation.string:minlen(1), t("can't be blank"), error_field_prefix)
      validate_field(errors, url_match, "backend_prefix", validation.string:minlen(1), t("can't be blank"), error_field_prefix)
    end
  end

  return errors
end

local function before_save(self, values)
  if values["servers"] then
    values["servers"] = cjson.encode(values["servers"])
  end

  if values["url_matches"] then
    values["url_matches"] = cjson.encode(values["url_matches"])
  end

  if values["settings"] then
    values["settings"] = cjson.encode(values["settings"])
  end

  if values["sub_settings"] then
    values["sub_settings"] = cjson.encode(values["sub_settings"])
  end

  if values["rewrites"] then
    values["rewrites"] = cjson.encode(values["rewrites"])
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
    ngx.log(ngx.ERR, "SELF: " .. inspect(self))
    local data = {
      id = self.id or json_null,
      name = self.name or json_null,
      backend_protocol = self.backend_protocol or json_null,
      frontend_host = self.frontend_host or json_null,
      backend_host = self.backend_host or json_null,
      balance_algorithm = self.balance_algorithm or json_null,
      servers = self.servers or {},
      url_matches = self.url_matches or {},
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
