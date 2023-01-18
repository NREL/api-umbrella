local capture_errors = require("lapis.application").capture_errors
local error_messages_by_field = require "api-umbrella.web-app.utils.error_messages_by_field"
local t = require("api-umbrella.web-app.utils.gettext").gettext

local _M = {}

local function errors_to_full_message_objects(errors)
  local full_messages = {}
  for _, error_data in ipairs(errors) do
    assert(error_data["code"])
    assert(error_data["field"])
    assert(error_data["field_label"])
    assert(error_data["message"])

    local full_message
    if error_data["field_label"] then
      full_message = string.format(t("%s: %s"), error_data["field_label"], error_data["message"])
    end

    table.insert(full_messages, {
      code = error_data["code"],
      message = error_data["message"],
      field = error_data["field"],
      full_message = full_message,
    })
  end

  return full_messages
end

local function error_response(errors, translate_to_full_messages)
  local status = 422
  if ngx.ctx.error_status then
    status = ngx.ctx.error_status
  end

  local json
  if errors and errors["_render"] then
    json = errors["_render"]
  else
    if translate_to_full_messages then
      json = {
        errors = errors_to_full_message_objects(errors),
      }
    else
      json = {
        errors = error_messages_by_field(errors),
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
