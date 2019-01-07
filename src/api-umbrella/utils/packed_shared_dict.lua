local cmsgpack = require "cmsgpack"

local pack = cmsgpack.pack
local unpack = cmsgpack.unpack

local _M = {}

function _M.get_packed(dict, key)
  local packed = dict:get(key)
  if packed then
    return unpack(packed)
  end
end

function _M.set_packed(dict, key, value)
  return dict:set(key, pack(value))
end

function _M.safe_set_packed(dict, key, value)
  return dict:safe_set(key, pack(value))
end

return _M
