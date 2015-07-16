local _M = {}

local inspect = require "inspect"
local utils = require "api-umbrella.proxy.utils"
local tablex = require "pl.tablex"

local worker_version
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
