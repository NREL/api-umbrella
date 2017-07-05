local app_helpers = require "lapis.application"

local capture_errors = app_helpers.capture_errors

local _M = {}

function _M.capture_errors_json(fn)
  return capture_errors(fn, function(self)
    return {
      status = 422,
      json = {
        errors = self.errors
      }
    }
  end)
end

return _M
