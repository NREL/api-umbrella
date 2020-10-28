local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local validate_field = model_ext.validate_field

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
    validate_field(errors, data, "api_backend_id", t("API backend"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
    })
    validate_field(errors, data, "matcher_type", t("Matcher type"), {
      { validation_ext:regex("^(route|regex)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "http_method", t("HTTP method"), {
      { validation_ext:regex("^(any|GET|POST|PUT|DELETE|HEAD|TRACE|OPTIONS|CONNECT|PATCH)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "frontend_matcher", t("Frontend matcher"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "backend_replacement", t("Backend replacement"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "sort_order", t("Sort order"), {
      { validation_ext.tonumber.number, t("can't be blank") },
    })
    return errors
  end,
})

return ApiBackendRewrite
