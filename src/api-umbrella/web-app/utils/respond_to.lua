local capture_errors = require("lapis.application").capture_errors

-- Based on Lapis' default respond_to implementation, this alternative
-- implementation allows us to return a 404 when the HTTP method is not found,
-- rather than raising an error (and generating a 500 error response).
--
-- If this (https://github.com/leafo/lapis/pull/339) gets merged, we could
-- possibly migrate to using 405 responses instead, but for now use 404s for
-- backwards compatibility.

local function run_before_filter(filter, self)
  local _write = self.write
  local written = false
  self.write = function(...)
    written = true
    return _write(...)
  end
  filter(self)
  self.write = _write
  return written
end

local function default_head()
  return {
    layout = false
  }
end

return function(tbl)
  if not tbl.HEAD then
    tbl.HEAD = default_head
  end

  local out = function(self)
    local fn = tbl[self.req.cmd_mth]
    if fn then
      local before = tbl.before
      if before then
        if run_before_filter(before, self) then
          return
        end
      end

      return fn(self)
    else
      return self.app.handle_404(self)
    end
  end

  local error_response = tbl.on_error
  if error_response then
    out = capture_errors(out, error_response)
  end

  return out
end
