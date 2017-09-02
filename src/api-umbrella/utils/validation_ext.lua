local db_null = require("lapis.db").NULL
local validation = require "resty.validation"

local function db_null_optional(default)
  return function(value)
    if value == nil or value == "" or value == db_null then
      return validation.stop, default ~= nil and default or value
    end
    return true, value
  end
end

local validators = validation.validators
local validators_metatable = getmetatable(validators)
validators.db_null_optional = db_null_optional()
validators_metatable.db_null_optional = db_null_optional
setmetatable(validators, validators_metatable)

return validation
