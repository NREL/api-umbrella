local is_empty = require("pl.types").is_empty

local _M = {}

local flash_session = require("resty.session").new({
  storage = "cookie",
  name = "_api_umbrella_messages",
  secret = config["web"]["rails_secret_token"],
})

function _M.now(self, flash_type, message)
  self.flash[flash_type] = message
end

function _M.session(_, flash_type, message)
  flash_session:start()
  flash_session.data[flash_type] = message
  flash_session:save()
end

function _M.setup(self)
  self.flash = {}

  self.restore_flashes = function()
    flash_session:open()
    if not is_empty(flash_session.data) then
      for flash_type, message in pairs(flash_session.data) do
        _M.now(self, flash_type, message)
      end

      flash_session:destroy()
    end

    return self.flash
  end
end

return _M
