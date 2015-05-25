local log_utils = require "log_utils"

if log_utils.ignore_request() then
  return
end

local ngx_var = ngx.var
local id = ngx_var.x_api_umbrella_request_id .. "_upstream_response_time"
ngx.shared.logs:set(id, tonumber(ngx_var.upstream_response_time), 60)
