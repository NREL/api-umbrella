local int64_to_json_number = require("api-umbrella.utils.int64").to_json_number
local json_null = require("cjson").null
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local validate_field = model_ext.validate_field

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
      id = json_null_default(self.id),
      duration = json_null_default(int64_to_json_number(self.duration)),
      accuracy = json_null,
      limit_by = json_null_default(self.limit_by),
      limit = json_null_default(int64_to_json_number(self.limit_to)),
      distributed = json_null_default(self.distributed),
      response_headers = json_null_default(self.response_headers),
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
    auto_calculate_distributed(values)

    -- Normalize the legacy value of "apiKey" to be stored internally as
    -- "api_key" (just be more consistent with the rest of the capitalization
    -- in all our values).
    if values["limit_by"] == "apiKey" then
      values["limit_by"] = "api_key"
    end
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "duration", t("Duration"), {
      { validation_ext.tonumber.number, t("can't be blank") },
    })
    validate_field(errors, data, "limit_by", t("Limit by"), {
      { validation_ext:regex("^(ip|api_key)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "limit_to", t("Limit"), {
      { validation_ext.tonumber.number, t("can't be blank"), },
    }, { error_field = "limit" })
    validate_field(errors, data, "distributed", t("Distributed"), {
      { validation_ext.boolean, t("can't be blank") },
    })

    return errors
  end,
})

return RateLimit
