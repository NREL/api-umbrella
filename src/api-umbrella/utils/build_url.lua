local ngx_var = ngx.var

return function(path)
  local host = ngx_var.http_x_forwarded_host or ngx_var.http_host or ngx_var.host
  local proto = ngx_var.http_x_forwarded_proto or ngx_var.scheme
  local port = ngx_var.http_x_forwarded_port or ngx_var.server_port

  return proto .. "://" .. host .. ":" .. port .. path
end
