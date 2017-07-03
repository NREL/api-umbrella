local Model = require("lapis.db.model").Model
local types = require "pl.types"
require "resty.validation.ngx"
local validation = require "resty.validation"
local iso8601 = require "api-umbrella.utils.iso8601"
local cjson = require "cjson"

local json_null = cjson.null
local is_empty = types.is_empty

local function validate(errors, values, key, validator, message)
  local value = values[key]
  local ok = validator(value)
  if not ok then
    if not errors[key] then
      errors[key] = {}
    end

    table.insert(errors[key], message)
  end
end

local function assert_valid(values)
  local errors = {}
  validate(errors, values, "name", validation.string:minlen(1), "can't be blank")
  validate(errors, values, "host", validation.string:minlen(1), "can't be blank")
  validate(errors, values, "host", validation:regex([[^(\*|(\*\.|\.)[a-zA-Z0-9:][a-zA-Z0-9\-\.:]*|[a-zA-Z0-9:][a-zA-Z0-9\-\.:]*)$]], "jo"), 'must be in the format of "example.com"')
  validate(errors, values, "path_prefix", validation.string:minlen(1), "can't be blank")
  validate(errors, values, "path_prefix", validation:regex("^/", "jo"), 'must start with "/"')

  if not is_empty(errors) then
    return coroutine.yield("error", errors)
  end
end

local ApiScope = Model:extend("api_scopes", {
  update = function(self, values)
    assert_valid(values)
    return Model.update(self, values)
  end,

  as_json = function(self)
    return {
      id = self.id or json_null,
      name = self.name or json_null,
      host = self.host or json_null,
      path_prefix = self.path_prefix or json_null,
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by or json_null,
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by or json_null,
      deleted_at = json_null,
      version = 1,
    }
  end,
})

function ApiScope.create(self, values, opts)
  assert_valid(values)
  return Model.create(self, values, opts)
end

return ApiScope
