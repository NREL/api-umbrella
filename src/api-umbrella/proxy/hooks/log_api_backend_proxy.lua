local log_utils = require "api-umbrella.proxy.log_utils"

if log_utils.ignore_request() then
  return
end

local ngx_var = ngx.var
local id = ngx_var.x_api_umbrella_request_id .. "_upstream_response_time"
local upstream_response_time = tonumber(ngx_var.upstream_response_time)
if upstream_response_time then
  ngx.shared.logs:set(id, upstream_response_time, 60)
end
