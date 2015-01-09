local _M = {}

local inspect = require "inspect"
local utils = require "utils"
local tablex = require "pl.tablex"

local worker_version
local data = {}

function _M.push(key, limit)
  if data[key] and data[key] > 0 then return end

  local expire_at = 0
  if limit then
    local ttl = limit["duration"]
    expire_at = ngx.now() * 1000 + ttl
  end

  data[key] = expire_at
end

function _M.fetch()
  local copy = tablex.deepcopy(data)
  data = {}
  return copy
end

return _M
