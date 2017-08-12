local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local validate_field = model_ext.validate_field

local ApiBackendRewrite = model_ext.new_class("api_backend_rewrites", {
  as_json = function(self)
    return {
      id = self.id or json_null,
      matcher_type = self.matcher_type or json_null,
      http_method = self.http_method or json_null,
      frontend_matcher = self.frontend_matcher or json_null,
      backend_replacement = self.backend_replacement or json_null,
    }
  end,
}, {
  validate = function(_, values)
    local errors = {}
    validate_field(errors, values, "matcher_type", validation:regex("^(route|regex)$", "jo"), t("is not included in the list"))
    validate_field(errors, values, "http_method", validation:regex("^(any|GET|POST|PUT|DELETE|HEAD|TRACE|OPTIONS|CONNECT|PATCH)$", "jo"), t("is not included in the list"))
    validate_field(errors, values, "frontend_matcher", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "backend_replacement", validation.string:minlen(1), t("can't be blank"))
    return errors
  end,
})

return ApiBackendRewrite
