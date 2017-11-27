local is_empty = require("pl.types").is_empty

local _M = {}

function _M.now(self, flash_type, message)
  self.flash[flash_type] = message
end

function _M.session(self, flash_type, message)
  self:init_session_client()
  self.resty_session_client:start()
  if not self.resty_session_client.data["flash"] then
    self.resty_session_client.data["flash"] = {}
  end
  self.resty_session_client.data["flash"][flash_type] = message
  self.resty_session_client:save()
end

function _M.setup(self)
  self.flash = {}

  self.restore_flashes = function()
    self:init_session_client()
    self.resty_session_client:open()
    if self.resty_session_client.data and not is_empty(self.resty_session_client.data["flash"]) then
      for flash_type, message in pairs(self.resty_session_client.data["flash"]) do
        _M.now(self, flash_type, message)
      end

      self.resty_session_client.data["flash"] = nil
      self.resty_session_client:save()
    end

    return self.flash
  end
end

return _M
