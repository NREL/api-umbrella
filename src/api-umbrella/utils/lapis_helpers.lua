local capture_errors = require("lapis.application").capture_errors
local is_hash = require "api-umbrella.utils.is_hash"

local _M = {}

function _M.capture_errors_json(fn)
  return capture_errors({
    on_error = function(self)
      local status = 422
      if self.errors and self.errors[1] and self.errors[1]["code"] == "FORBIDDEN" then
        status = 403
      end

      return {
        status = status,
        json = {
          errors = self.errors,
        }
      }
    end,
    fn,
  })
end

function _M.capture_errors_json_full(fn)
  return capture_errors({
    on_error = function(self)
      local response = self.errors
      local status = 422
      if self.errors and self.errors[1] and self.errors[1]["code"] == "FORBIDDEN" then
        status = 403
      elseif is_hash(self.errors) then
        response = {}
        for field, field_messages in pairs(self.errors) do
          for _, message in ipairs(field_messages) do
            local human_field = string.gsub(field, "_", " ")
            human_field = string.gsub(human_field, "(%l)(%w*)", function(first, rest) return string.upper(first) .. rest end)
            local full_message = human_field .. ": " .. message
            table.insert(response, {
              code = "INVALID_INPUT",
              message = message,
              field = field,
              full_message = full_message,
            })
          end
        end
      end

      return {
        status = status,
        json = {
          errors = response,
        }
      }
    end,
    fn,
  })
end

return _M
