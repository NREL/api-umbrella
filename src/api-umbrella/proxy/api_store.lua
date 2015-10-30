local _M = {}

local utils = require "api-umbrella.proxy.utils"

local get_packed = utils.get_packed

function _M.all_apis()
  local data = get_packed(ngx.shared.active_config, "packed_data") or {}
  return data["apis"] or {}
end

return _M
