local common_validations = require "api-umbrella.utils.common_validations"
local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation_ext = require "api-umbrella.utils.validation_ext"

local validate_field = model_ext.validate_field
local validate_uniqueness = model_ext.validate_uniqueness

local ApiBackendUrlMatch
ApiBackendUrlMatch = model_ext.new_class("api_backend_url_matches", {
  as_json = function(self)
    return {
      id = self.id or json_null,
      frontend_prefix = self.frontend_prefix or json_null,
      backend_prefix = self.backend_prefix or json_null,
    }
  end,
}, {
  authorize = function()
    return true
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "api_backend_id", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "frontend_prefix", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "frontend_prefix", validation_ext.db_null_optional:regex(common_validations.url_prefix_format, "jo"), t('must start with "/"'))
    validate_field(errors, data, "backend_prefix", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "backend_prefix", validation_ext.db_null_optional:regex(common_validations.url_prefix_format, "jo"), t('must start with "/"'))
    validate_uniqueness(errors, data, "frontend_prefix", ApiBackendUrlMatch, {
      "api_backend_id",
      "frontend_prefix",
    })
    validate_uniqueness(errors, data, "sort_order", ApiBackendUrlMatch, {
      "api_backend_id",
      "sort_order",
    })
    return errors
  end,
})

return ApiBackendUrlMatch
