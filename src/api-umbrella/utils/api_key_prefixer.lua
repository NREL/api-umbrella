local API_KEY_PREFIX_LENGTH = 16

local _M = {}

_M.API_KEY_PREFIX_LENGTH = API_KEY_PREFIX_LENGTH

function _M.prefix(api_key)
  return string.sub(api_key, 1, API_KEY_PREFIX_LENGTH)
end

return _M
