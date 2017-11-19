local capture_errors = require("lapis.application").capture_errors
local is_hash = require "api-umbrella.utils.is_hash"

local _M = {}

local function messages_to_full_message_objects(errors)
  local full_messages = {}
  for field, field_messages in pairs(errors) do
    for _, message in ipairs(field_messages) do
      local human_field = string.gsub(field, "_", " ")
      human_field = string.gsub(human_field, "(%l)(%w*)", function(first, rest) return string.upper(first) .. rest end)
      local full_message = human_field .. ": " .. message
      table.insert(full_messages, {
        code = "INVALID_INPUT",
        message = message,
        field = field,
        full_message = full_message,
      })
    end
  end

  return full_messages
end

local function error_response(errors, translate_to_full_messages)
  local status = 422
  if ngx.ctx.error_status then
    status = ngx.ctx.error_status
  end

  local json
  if ngx.ctx.error_no_wrap then
    json = errors
  else
    if translate_to_full_messages and is_hash(errors) and (not errors[1] or not errors[1]["code"]) then
      json = {
        errors = messages_to_full_message_objects(errors),
      }
    else
      json = {
        errors = errors,
      }
    end
  end

  return {
    status = status,
    json = json,
  }
end

function _M.json(fn)
  return capture_errors({
    on_error = function(self)
      return error_response(self.errors, false)
    end,
    fn,
  })
end

function _M.json_full(fn)
  return capture_errors({
    on_error = function(self)
      return error_response(self.errors, true)
    end,
    fn,
  })
end

return _M
