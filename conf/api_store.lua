local _M = {}

local inspect = require "inspect"
local utils = require "utils"

local append_array = utils.append_array
local get_packed = utils.get_packed

function _M.all_apis(host)
  local data = get_packed(ngx.shared.apis, "packed_data")

  local all_apis = {}
  if data and data["apis_by_host"] then
    for _, apis_for_host in pairs(data["apis_by_host"]) do
      append_array(all_apis, apis_for_host)
    end
  end

  return all_apis
end

function _M.for_host(host)
  local data = get_packed(ngx.shared.apis, "packed_data") or {}
  if host and data["apis_by_host"] then
    return data["apis_by_host"][host]
  end
end

return _M
