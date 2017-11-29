local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local validate_field = model_ext.validate_field
local validate_uniqueness = model_ext.validate_uniqueness

local ApiBackendRewrite
ApiBackendRewrite = model_ext.new_class("api_backend_rewrites", {
  as_json = function(self)
    return {
      id = json_null_default(self.id),
      matcher_type = json_null_default(self.matcher_type),
      http_method = json_null_default(self.http_method),
      frontend_matcher = json_null_default(self.frontend_matcher),
      backend_replacement = json_null_default(self.backend_replacement),
    }
  end,
}, {
  authorize = function()
    return true
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "api_backend_id", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "matcher_type", validation_ext:regex("^(route|regex)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "http_method", validation_ext:regex("^(any|GET|POST|PUT|DELETE|HEAD|TRACE|OPTIONS|CONNECT|PATCH)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "frontend_matcher", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "backend_replacement", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "sort_order", validation_ext.tonumber.number, t("can't be blank"))
    validate_uniqueness(errors, data, "frontend_matcher", ApiBackendRewrite, {
      "api_backend_id",
      "matcher_type",
      "http_method",
      "frontend_matcher",
    })
    validate_uniqueness(errors, data, "sort_order", ApiBackendRewrite, {
      "api_backend_id",
      "sort_order",
    })
    return errors
  end,
})

return ApiBackendRewrite
