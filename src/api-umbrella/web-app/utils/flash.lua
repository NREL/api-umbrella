local is_empty = require("pl.types").is_empty

local _M = {}

function _M.now(self, flash_type, message)
  self.flash[flash_type] = message
end

function _M.session(self, flash_type, message)
  self:init_session_cookie()
  self.session_cookie:start()
  if not self.session_cookie.data["flash"] then
    self.session_cookie.data["flash"] = {}
  end
  self.session_cookie.data["flash"][flash_type] = message
  self.session_cookie:save()
end

function _M.setup(self)
  self.flash = {}

  self.restore_flashes = function()
    self:init_session_cookie()
    self.session_cookie:open()
    if self.session_cookie.data and not is_empty(self.session_cookie.data["flash"]) then
      for flash_type, message in pairs(self.session_cookie.data["flash"]) do
        _M.now(self, flash_type, message)
      end

      self.session_cookie.data["flash"] = nil
      self.session_cookie:save()
    end

    return self.flash
  end
end

return _M
