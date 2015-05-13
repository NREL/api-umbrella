local _M = {}

local inspect = require "inspect"
local utils = require "utils"
local tablex = require "pl.tablex"

local worker_version
local data = {}

function _M.push(key)
  data[key] = 1
end

function _M.fetch()
  local copy = tablex.copy(data)
  data = {}
  return copy
end

return _M
