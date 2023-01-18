local encryptor = require "api-umbrella.utils.encryptor"

local _M = {}
_M.__index = _M

function _M.new()
  return setmetatable({}, _M)
end

function _M.encrypt(_, data, _, id, auth_data)
  local iv = string.sub(id, 1, 12)
  local encrypted, _ = encryptor.encrypt(data, auth_data, {
    iv = iv,
    base64 = false,
  })

  return encrypted
end

function _M.decrypt(_, encrypted_data, _, id, auth_data)
  local iv = string.sub(id, 1, 12)
  return encryptor.decrypt(encrypted_data, iv, auth_data, {
    base64 = false,
  })
end

return _M
