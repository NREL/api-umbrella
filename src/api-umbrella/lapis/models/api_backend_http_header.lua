local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local validate_field = model_ext.validate_field

local ApiBackendHttpHeader = model_ext.new_class("api_backend_http_headers", {
  string_value = function(self)
    return self.key .. ": " .. (self.value or "")
  end,

  as_json = function(self)
    return {
      id = self.id or json_null,
      key = self.key or json_null,
      value = self.value or json_null,
    }
  end,
}, {
  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "header_type", validation:regex("^(request|response_default|response_override)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "sort_order", validation.number, t("can't be blank"))
    validate_field(errors, data, "key", validation.string:minlen(1), t("can't be blank"))
    return errors
  end,
})

return ApiBackendHttpHeader
