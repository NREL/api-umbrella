local RateLimit = require "api-umbrella.web-app.models.rate_limit"
local db = require "lapis.db"
local is_array = require "api-umbrella.utils.is_array"
local json_array_fields = require "api-umbrella.web-app.utils.json_array_fields"
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local pg_encode_array = require "api-umbrella.utils.pg_encode_array"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local db_null = db.NULL
local db_raw = db.raw
local validate_field = model_ext.validate_field
local validate_relation_uniqueness = model_ext.validate_relation_uniqueness

local ApiUserSettings = model_ext.new_class("api_user_settings", {
  relations = {
    {
      "rate_limits",
      has_many = "RateLimit",
      key = "api_user_settings_id",
      order = "duration, limit_by",
    },
  },

  as_json = function(self, options)
    local data = {
      id = json_null_default(self.id),
      allowed_ips = json_null_default(self.allowed_ips),
      allowed_referers = json_null_default(self.allowed_referers),
      rate_limit_mode = json_null_default(self.rate_limit_mode),
      rate_limits = {},
    }

    local rate_limits = self:get_rate_limits()
    for _, rate_limit in ipairs(rate_limits) do
      table.insert(data["rate_limits"], rate_limit:as_json(options))
    end

    json_array_fields(data, {"rate_limits"}, options)

    return data
  end,

  rate_limits_update_or_create = function(self, rate_limit_values)
    return model_ext.has_many_update_or_create(self, RateLimit, "api_user_settings_id", rate_limit_values)
  end,

  rate_limits_delete_except = function(self, keep_rate_limit_ids)
    return model_ext.has_many_delete_except(self, RateLimit, "api_user_settings_id", keep_rate_limit_ids)
  end,
}, {
  authorize = function()
    return true
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "allowed_ips", t("Restrict Access to IPs"), {
      { validation_ext.db_null_optional.array_table, t("is not an array") },
      { validation_ext.db_null_optional.array_strings, t("must be an array of strings") },
      { validation_ext.db_null_optional.array_strings_ips, t("invalid IP") },
    })
    validate_field(errors, data, "allowed_referers", t("Restrict Access to HTTP Referers"), {
      { validation_ext.db_null_optional.array_table, t("is not an array") },
      { validation_ext.db_null_optional.array_strings, t("must be an array of strings") },
      { validation_ext.db_null_optional:array_strings_maxlen(500), string.format(t("is too long (maximum is %d characters)"), 500) },
    })
    validate_field(errors, data, "rate_limit_mode", t("Rate limit mode"), {
      { validation_ext.db_null_optional:regex("^(unlimited|custom)$", "jo"), t("is not included in the list") },
    })
    validate_relation_uniqueness(errors, data, "rate_limits", "duration", t("Duration"), {
      "api_user_settings_id",
      "limit_by",
      "duration",
    })

    return errors
  end,

  before_save = function(_, values)
    if is_array(values["allowed_ips"]) and values["allowed_ips"] ~= db_null then
      values["allowed_ips"] = db_raw(pg_encode_array(values["allowed_ips"]) .. "::inet[]")
    end

    if is_array(values["allowed_referers"]) and values["allowed_referers"] ~= db_null then
      values["allowed_referers"] = db_raw(pg_encode_array(values["allowed_referers"]))
    end
  end,

  after_save = function(self, values)
    model_ext.has_many_save(self, values, "rate_limits")
  end
})

return ApiUserSettings
