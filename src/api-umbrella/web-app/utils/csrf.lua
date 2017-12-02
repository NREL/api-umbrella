local hmac = require "api-umbrella.utils.hmac"
local json_encode = require "api-umbrella.utils.json_encode"
local lapis_csrf = require "lapis.csrf"
local random_token = require "api-umbrella.utils.random_token"
local t = require("api-umbrella.web-app.utils.gettext").gettext

local _M = {}

function _M.generate_token(self)
  -- Generate a random key and store it in the cookie session. The key is
  -- necessary for Lapi's CSRF protection to actually be effective:
  -- https://github.com/leafo/lapis/issues/219
  self:init_session_cookie()
  self.session_cookie:start()
  local csrf_token_key = self.session_cookie.data["csrf_token_key"]
  if not csrf_token_key then
    csrf_token_key = random_token(40)
    self.session_cookie.data["csrf_token_key"] = csrf_token_key
    self.session_cookie:save()
  end

  return lapis_csrf.generate_token(self, csrf_token_key)
end

function _M.validate_token_filter(fn)
  return function(self, ...)
    self:init_session_cookie()
    self.session_cookie:open()
    local key = self.session_cookie.data["csrf_token_key"]

    local valid = false
    local err
    if not key then
      err = "Missing CSRF token key"
    else
      if not self.params.csrf_token and ngx.var.http_x_csrf_token then
        self.params.csrf_token = ngx.var.http_x_csrf_token
      end
      valid, err = lapis_csrf.validate_token(self, key)
    end

    if not valid then
      ngx.log(ngx.WARN, "CSRF validation failure: ", err)

      ngx.status = 422
      ngx.header["Content-Type"] = "application/json; charset=utf-8"
      ngx.say(json_encode({
        ["error"] = t("Unprocessable Entity"),
      }))
      ngx.exit(ngx.HTTP_OK)

      return self:write({ layout = false })
    elseif fn then
      return fn(self, ...)
    end
  end
end

-- This can be used to replace the default "validate_token_filter" CSRF
-- protection in cases where the endpoint may be hit via ajax by an admin (with
-- the X-Admin-Auth-Token header provided), or via a server-side submit (in
-- which case the default CSRF token will be present).
--
-- If the "X-Admin-Auth-Token" header is being passed in, then we can consider
-- that an effective replacement of the CSRF token value (since only a local
-- application should have knowledge of this token). But if this auth token
-- isn't passed in, then we fallback to the default CSRF logic in
-- "validate_token_filter".
function _M.validate_token_or_admin_filter(fn)
  return function(self, ...)
    local skip_csrf = false
    local auth_token = ngx.var.http_x_admin_auth_token
    if auth_token and self.current_admin then
      local auth_token_hmac = hmac(auth_token)
      if auth_token_hmac == self.current_admin.authentication_token_hash then
        skip_csrf = true
      end
    end

    if not skip_csrf then
      return _M.validate_token_filter(fn)(self)
    elseif fn then
      return fn(self, ...)
    end
  end
end

return _M
