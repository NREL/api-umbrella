local ApiBackendSettings = require "api-umbrella.web-app.models.api_backend_settings"
local json_null = require("cjson").null
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local validate_field = model_ext.validate_field

local ApiBackendSubUrlSettings
ApiBackendSubUrlSettings = model_ext.new_class("api_backend_sub_url_settings", {
  relations = {
    { "settings", has_one = "ApiBackendSettings", key = "api_backend_sub_url_settings_id" },
  },

  as_json = function(self, options)
    local data = {
      id = json_null_default(self.id),
      http_method = json_null_default(self.http_method),
      regex = json_null_default(self.regex),
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
    return model_ext.has_one_delete(self, ApiBackendSettings, "api_backend_sub_url_settings_id")
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
    validate_field(errors, data, "http_method", t("HTTP method"), {
      { validation_ext:regex("^(any|GET|POST|PUT|DELETE|HEAD|TRACE|OPTIONS|CONNECT|PATCH)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "regex", t("Regex"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "sort_order", t("Sort order"), {
      { validation_ext.tonumber.number, t("can't be blank") },
    })
    return errors
  end,

  after_save = function(self, values)
    model_ext.has_one_save(self, values, "settings")
  end,
})

return ApiBackendSubUrlSettings
