local invert_table = require "api-umbrella.utils.invert_table"
local split = require("ngx.re").split

return function()
  if not ngx.ctx.request_api_umbrella_roles then
    local roles = ngx.var.http_x_api_roles
    if roles then
      ngx.ctx.request_api_umbrella_roles = invert_table(split(roles, ",", "jo"))
    else
      ngx.ctx.request_api_umbrella_roles = {}
    end
  end

  return ngx.ctx.request_api_umbrella_roles
end
