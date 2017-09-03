local capture_errors = require("lapis.application").capture_errors

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
          errors = self.errors
        }
      }
    end,
    fn,
  })
end

return _M
