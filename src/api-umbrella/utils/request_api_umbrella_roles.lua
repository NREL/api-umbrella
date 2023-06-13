local invert_table = require "api-umbrella.utils.invert_table"
local split = require("ngx.re").split

local ngx_var = ngx.var

return function(ngx_ctx)
  if not ngx_ctx.request_api_umbrella_roles then
    local roles = ngx_var.http_x_api_roles
    if roles then
      ngx_ctx.request_api_umbrella_roles = invert_table(split(roles, ",", "jo"))
    else
      ngx_ctx.request_api_umbrella_roles = {}
    end
  end

  return ngx_ctx.request_api_umbrella_roles
end
