local host_normalize = require "api-umbrella.utils.host_normalize"

local ngx_var = ngx.var

return function(path)
  local host = ngx_var.http_x_forwarded_host or ngx_var.http_host or ngx_var.host
  local proto = ngx_var.http_x_forwarded_proto or ngx_var.scheme
  local port = tonumber(ngx_var.http_x_forwarded_port or ngx_var.server_port)

  local url = proto .. "://" .. host_normalize(host)
  if (proto == "https" and port ~= 443) or (proto == "http" and port ~= 80)then
    url = url .. ":" .. port
  end
  url = url .. path

  return url
end
