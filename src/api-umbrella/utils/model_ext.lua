local Model = require("lapis.db.model").Model
local uuid = require "resty.uuid"
local types = require "pl.types"

require "resty.validation.ngx"

local uuid_generate = uuid.generate_random
local is_empty = types.is_empty

local _M = {}

function _M.validate_field(errors, values, field, validator, message)
  local value = values[field]
  local ok = validator(value)
  if not ok then
    if not errors[field] then
      errors[field] = {}
    end

    table.insert(errors[field], message)
  end
end

function _M.create(options)
  return function(self, values, opts)
    if not values["id"] then
      values["id"] = uuid_generate()
    end

    if options["before_create"] then
      options["before_create"](self, values)
    end

    if options["validate"] then
      local errors = options["validate"](values)
      if not is_empty(errors) then
        return coroutine.yield("error", errors)
      end
    end

    return Model.create(self, values, opts)
  end
end

function _M.update(options)
  return function(self, values)
    if options["validate"] then
      local errors = options["validate"](values)
      if not is_empty(errors) then
        return coroutine.yield("error", errors)
      end
    end

    return Model.update(self, values)
  end
end

return _M
