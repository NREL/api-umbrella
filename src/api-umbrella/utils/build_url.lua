local ngx_var = ngx.var

return function(path)
  local host = ngx_var.http_x_forwarded_host or ngx_var.http_host or ngx_var.host
  local proto = ngx_var.http_x_forwarded_proto or ngx_var.scheme

  return proto .. "://" .. host .. path
end
