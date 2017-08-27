local capture_errors = require("lapis.application").capture_errors

local _M = {}

function _M.capture_errors_json(fn)
  return capture_errors({
    on_error = function(self)
      return {
        status = 422,
        json = {
          errors = self.errors
        }
      }
    end,
    fn,
  })
end

return _M
