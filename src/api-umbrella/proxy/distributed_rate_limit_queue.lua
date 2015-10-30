local _M = {}

local tablex = require "pl.tablex"

local data = {}

function _M.push(key)
  data[key] = (data[key] or 0) + 1
end

function _M.pop()
  local copy = tablex.copy(data)
  data = {}
  return copy
end

return _M
