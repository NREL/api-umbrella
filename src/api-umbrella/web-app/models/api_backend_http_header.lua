local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local validate_field = model_ext.validate_field

local ApiBackendHttpHeader = model_ext.new_class("api_backend_http_headers", {
  string_value = function(self)
    return self.key .. ": " .. (self.value or "")
  end,

  as_json = function(self)
    return {
      id = json_null_default(self.id),
      key = json_null_default(self.key),
      value = json_null_default(self.value),
    }
  end,
}, {
  authorize = function()
    return true
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "header_type", t("Header type"), {
      { validation_ext:regex("^(request|response_default|response_override)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "sort_order", t("Sort order"), {
      { validation_ext.tonumber.number, t("can't be blank") },
    })
    validate_field(errors, data, "key", t("Key"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "value", t("Value"), {
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    return errors
  end,
})

return ApiBackendHttpHeader
