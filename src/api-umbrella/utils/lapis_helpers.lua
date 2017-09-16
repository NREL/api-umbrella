local capture_errors = require("lapis.application").capture_errors
local is_empty = require("pl.types").is_empty
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

function _M.capture_errors_json(fn)
  return capture_errors({
    on_error = function(self)
      return error_response(self.errors, false)
    end,
    fn,
  })
end

function _M.capture_errors_json_full(fn)
  return capture_errors({
    on_error = function(self)
      return error_response(self.errors, true)
    end,
    fn,
  })
end

-- This allows us to support IE8-9 and their shimmed pseudo-CORS support. This
-- parses the post body as form data, even if the content-type is text/plain or
-- unknown.
--
-- The issue is that IE8-9 will send POST data with an empty Content-Type (see:
-- http://goo.gl/oumNaF). To handle this, we force parsing of our post body as
-- form data so IE's form data is present on the normal "params" object. Also
-- note that apparently historically IE8-9 would actually send the data as
-- "text/plain" rather than an empty content-type, so we handle any content
-- type.
function _M.parse_post_for_pseudo_ie_cors(fn)
  return function(self, ...)
    if ngx.req.get_method() == "POST" and is_empty(self.POST) then
      ngx.req.read_body()
      local args = ngx.req.get_post_args()
      local support = self.__class.support
      support.add_params(self, args, "POST")
    end

    return fn(self, ...)
  end
end

return _M
