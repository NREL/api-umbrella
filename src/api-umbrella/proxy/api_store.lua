local _M = {}

local inspect = require "inspect"
local utils = require "api-umbrella.proxy.utils"

local append_array = utils.append_array
local get_packed = utils.get_packed

function _M.all_apis(host)
  local data = get_packed(ngx.shared.active_config, "packed_data") or {}
  return data["apis"] or {}
end

return _M
