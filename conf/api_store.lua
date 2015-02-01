local _M = {}

local inspect = require "inspect"
local utils = require "utils"

local worker_version = 0
local data = {}

function _M.all_apis(host)
  return data["apis"] or {}
end

function _M.version(host)
  return worker_version
end

function _M.for_host(host)
  if DEBUG then _M.update_worker_cache_if_necessary() end

  if host and data["apis_by_host"] then
    return data["apis_by_host"][host]
  end
end

function _M.update_worker_cache(version)
  version = version or ngx.shared.apis:get("version") or 0
  local shared_data = utils.get_packed(ngx.shared.apis, "packed_data") or {}

  if shared_data["apis"] and shared_data["ids_by_host"] then
    shared_data["apis_by_host"] = {}
    for host, api_ids in pairs(shared_data["ids_by_host"]) do
      for _, api_id in ipairs(api_ids) do
        if not shared_data["apis_by_host"][host] then
          shared_data["apis_by_host"][host] = {}
        end

        local api = shared_data["apis"][api_id]
        table.insert(shared_data["apis_by_host"][host], api)
      end
    end
  end

  data = shared_data
  worker_version = version
end

function _M.update_worker_cache_if_necessary()
  local version = ngx.shared.apis:get("version") or 0
  if version > worker_version then
    _M.update_worker_cache(version)
  end
end

return _M
