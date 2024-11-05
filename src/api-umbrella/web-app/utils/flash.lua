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
  self.session_cookie:open()
  local flash = self.session_cookie:get("flash")
  if not flash then
    flash = {}
  end
  flash[flash_type] = data
  self.session_cookie:set("flash", flash)
  self.session_cookie:save()
end

function _M.setup(self)
  self.flash = {}

  self.restore_flashes = function()
    self:init_session_cookie()
    self.session_cookie:open()
    local flash_value = self.session_cookie:get("flash")
    if not is_empty(flash_value) then
      for flash_type, data in pairs(flash_value) do
        _M.now(self, flash_type, data["message"], data)
      end

      self.session_cookie:set("flash", nil)
      self.session_cookie:save()
    end

    return self.flash
  end
end

return _M
