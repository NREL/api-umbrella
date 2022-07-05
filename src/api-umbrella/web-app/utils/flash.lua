local is_empty = require "api-umbrella.utils.is_empty"

local _M = {}

function _M.now(self, flash_type, message, options)
  local data = options or {}
  data["message"] = message

  self.flash[flash_type] = data
end

function _M.session(self, flash_type, message, options)
  local data = options or {}
  data["message"] = message

  self:init_session_cookie()
  self.session_cookie:start()
  if not self.session_cookie.data["flash"] then
    self.session_cookie.data["flash"] = {}
  end
  self.session_cookie.data["flash"][flash_type] = data
  self.session_cookie:save()
end

function _M.setup(self)
  self.flash = {}

  self.restore_flashes = function()
    self:init_session_cookie()
    local _, _, open_err = self.session_cookie:start()
    if open_err then
      ngx.log(ngx.ERR, "session open error: ", open_err)
    end

    if self.session_cookie.data and not is_empty(self.session_cookie.data["flash"]) then
      for flash_type, data in pairs(self.session_cookie.data["flash"]) do
        _M.now(self, flash_type, data["message"], data)
      end

      self.session_cookie.data["flash"] = nil
      self.session_cookie:save()
    end

    return self.flash
  end
end

return _M
