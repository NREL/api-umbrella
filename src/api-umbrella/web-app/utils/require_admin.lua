local json_encode = require "api-umbrella.utils.json_encode"
local t = require("api-umbrella.web-app.utils.gettext").gettext

return function(fn)
  return function(self, ...)
    -- If the admin isn't set, call Lapis' self:write to halt execution of the
    -- current method.
    if not self.current_admin then
      -- Lapis' self:write without layout false doesn't seem to be working in
      -- this specific before filter context for some reason (some combination
      -- of layout = false and json), so drop down and use the lower-level
      -- nginx APIs to return this JSON response.
      ngx.status = 401
      ngx.header["Content-Type"] = "application/json; charset=utf-8"
      ngx.say(json_encode({
        ["error"] = t("You need to sign in or sign up before continuing."),
      }))
      ngx.exit(ngx.HTTP_OK)

      return self:write({ layout = false })
    end

    if fn then
      return fn(self, ...)
    end
  end
end
