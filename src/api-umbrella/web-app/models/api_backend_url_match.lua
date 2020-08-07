local common_validations = require "api-umbrella.web-app.utils.common_validations"
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local validate_field = model_ext.validate_field

local ApiBackendUrlMatch
ApiBackendUrlMatch = model_ext.new_class("api_backend_url_matches", {
  as_json = function(self)
    return {
      id = json_null_default(self.id),
      frontend_prefix = json_null_default(self.frontend_prefix),
      backend_prefix = json_null_default(self.backend_prefix),
    }
  end,
}, {
  authorize = function()
    return true
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "api_backend_id", t("API backend"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
    })
    validate_field(errors, data, "frontend_prefix", t("Frontend prefix"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional:regex(common_validations.url_prefix_format, "jo"), t('must start with "/"') },
    })
    validate_field(errors, data, "backend_prefix", t("Backend prefix"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional:regex(common_validations.url_prefix_format, "jo"), t('must start with "/"') },
    })
    return errors
  end,
})

return ApiBackendUrlMatch
