local ApiBackendSettings = require "api-umbrella.lapis.models.api_backend_settings"
local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation_ext = require "api-umbrella.utils.validation_ext"

local validate_field = model_ext.validate_field
local validate_uniqueness = model_ext.validate_uniqueness

local ApiBackendSubUrlSettings
ApiBackendSubUrlSettings = model_ext.new_class("api_backend_sub_url_settings", {
  relations = {
    { "settings", has_one = "ApiBackendSettings", key = "api_backend_sub_url_settings_id" },
  },

  as_json = function(self, options)
    local data = {
      id = self.id or json_null,
      http_method = self.http_method or json_null,
      regex = self.regex or json_null,
      settings = json_null,
    }

    local settings = self:get_settings()
    if settings then
      data["settings"] = settings:as_json(options)
    end

    return data
  end,

  settings_update_or_create = function(self, settings_values)
    return model_ext.has_one_update_or_create(self, ApiBackendSettings, "api_backend_sub_url_settings_id", settings_values)
  end,

  settings_delete = function(self)
    return model_ext.has_one_delete(self, ApiBackendSettings, "api_backend_sub_url_settings_id", {})
  end,
}, {
  authorize = function()
    return true
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "api_backend_id", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "http_method", validation_ext:regex("^(any|GET|POST|PUT|DELETE|HEAD|TRACE|OPTIONS|CONNECT|PATCH)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "regex", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "sort_order", validation_ext.number, t("can't be blank"))
    validate_uniqueness(errors, data, "regex", ApiBackendSubUrlSettings, {
      "api_backend_id",
      "http_method",
      "regex",
    })
    validate_uniqueness(errors, data, "sort_order", ApiBackendSubUrlSettings, {
      "api_backend_id",
      "sort_order",
    })
    return errors
  end,

  after_save = function(self, values)
    model_ext.has_one_save(self, values, "settings")
  end,
})

return ApiBackendSubUrlSettings
