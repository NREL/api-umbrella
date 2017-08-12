local common_validations = require "api-umbrella.utils.common_validations"
local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local validate_field = model_ext.validate_field

local ApiBackendUrlMatch = model_ext.new_class("api_backend_url_matches", {
  as_json = function(self)
    return {
      id = self.id or json_null,
      frontend_prefix = self.frontend_prefix or json_null,
      backend_prefix = self.backend_prefix or json_null,
    }
  end,
}, {
  validate = function(_, values)
    local errors = {}
    validate_field(errors, values, "frontend_prefix", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "frontend_prefix", validation.optional:regex(common_validations.url_prefix_format, "jo"), t('must start with "/"'))
    validate_field(errors, values, "backend_prefix", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "backend_prefix", validation.optional:regex(common_validations.url_prefix_format, "jo"), t('must start with "/"'))
    return errors
  end,
})

return ApiBackendUrlMatch
