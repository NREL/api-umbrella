local db = require "lapis.db"
local int64_to_json_number = require("api-umbrella.utils.int64").to_json_number
local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation_ext = require "api-umbrella.utils.validation_ext"

local db_null = db.NULL
local validate_field = model_ext.validate_field
local validate_uniqueness = model_ext.validate_uniqueness

local function auto_calculate_accuracy(values)
  if values["accuracy"] ~= nil then
    return
  end

  if values["duration"] then
    local duration_seconds = values["duration"] / 1000.0

    local accuracy_seconds
    if duration_seconds <= 1 then -- 1 second
      accuracy_seconds = 0.5
    elseif duration_seconds <= 30 then -- 30 seconds
      accuracy_seconds = 1
    elseif duration_seconds <= 2 * 60 then -- 2 minutes
      accuracy_seconds = 5
    elseif duration_seconds <= 10 * 60 then -- 10 minutes
      accuracy_seconds = 30
    elseif duration_seconds <= 1 * 60 * 60 then -- 1 hour
      accuracy_seconds = 1 * 60 -- 1 minute
    elseif duration_seconds <= 10 * 60 * 60 then -- 10 hours
      accuracy_seconds = 10 * 60 -- 10 minutes
    elseif duration_seconds <= 1 * 24 * 60 * 60 then -- 1 day
      accuracy_seconds = 30 * 60 -- 30 minutes
    elseif duration_seconds <= 2 * 24 * 60 * 60 then -- 2 days
      accuracy_seconds = 1 * 60 * 60 -- 1 hour
    elseif duration_seconds <= 7 * 24 * 60 * 60 then -- 7 days
      accuracy_seconds = 6 * 60 * 60 -- 6 hours
    else
      accuracy_seconds = 1 * 24 * 60 * 60 -- 1 day
    end

    local accuracy_ms = accuracy_seconds * 1000
    values["accuracy"] = accuracy_ms
  end
end

local function auto_calculate_distributed(values)
  if values["distributed"] ~= nil then
    return
  end

  if values["duration"] and values["duration"] > 10000 then
    values["distributed"] = true
  else
    values["distributed"] = false
  end
end

local RateLimit
RateLimit = model_ext.new_class("rate_limits", {
  as_json = function(self)
    local data = {
      id = self.id or json_null,
      duration = int64_to_json_number(self.duration) or json_null,
      accuracy = int64_to_json_number(self.accuracy) or json_null,
      limit_by = self.limit_by or json_null,
      limit = int64_to_json_number(self.limit_to) or json_null,
      distributed = self.distributed or json_null,
      response_headers = self.response_headers or json_null,
    }

    -- Return the legacy capitalization of "apiKey" for backwards compatibility
    -- (revisit if we introduce v2 of the API).
    if data["limit_by"] == "api_key" then
      data["limit_by"] = "apiKey"
    end

    return data
  end,
}, {
  authorize = function()
    return true
  end,

  before_validate = function(_, values)
    auto_calculate_accuracy(values)
    auto_calculate_distributed(values)

    -- Normalize the legacy value of "apiKey" to be stored internally as
    -- "api_key" (just be more consistent with the rest of the capitalization
    -- in all our values).
    if values["limit_by"] == "apiKey" then
      values["limit_by"] = "api_key"
    end
  end,

  validate = function(_, data, values)
    local errors = {}
    validate_field(errors, data, "duration", validation_ext.number, t("can't be blank"))
    validate_field(errors, data, "accuracy", validation_ext.number, t("can't be blank"))
    validate_field(errors, data, "limit_by", validation_ext:regex("^(ip|api_key)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "limit_to", validation_ext.number, t("can't be blank"), { error_field = "limit" })
    validate_field(errors, data, "distributed", validation_ext.boolean, t("can't be blank"))

    local settings_id_column = "api_backend_settings_id"
    if data["api_user_settings_id"] and data["api_user_settings_id"] ~= db_null then
      settings_id_column = "api_user_settings_id"
    end
    validate_uniqueness(errors, data, "duration", RateLimit, {
      settings_id_column,
      "limit_by",
      "duration",
    })

    return errors
  end,
})

return RateLimit
