local _M = {}

local cmsgpack = require "cmsgpack"
local moses = require "moses"

function _M.base_url()
  local protocol = ngx.var.http_x_forwarded_proto or ngx.var.scheme
  local host = ngx.var.http_x_forwarded_host or ngx.var.host
  local port = ngx.var.http_x_forwarded_port or ngx.var.server_port

  local base = protocol .. "://" .. host
  if (protocol == "http" and port ~= "80") or (protocol == "https" and port ~= "443") then
    base = base .. ":" .. port
  end

  return base
end

function _M.get_packed(dict, key)
  local packed = dict:get(key)
  if packed then
    return cmsgpack.unpack(packed)
  end
end

function _M.set_packed(dict, key, value)
  return dict:set(key, cmsgpack.pack(value))
end

function _M.deep_merge_overwrite_arrays(t1, t2)
  for key, value in pairs(t2) do
    if moses.isTable(value) and moses.isTable(t1[key]) then
      if moses.isArray(value) then
        t1[key] = value
      else
        merge(t1[key], t2[key])
      end
    else
      t1[key] = value
    end
  end
  return t1
end

return _M
