local wait_for_setup = require "api-umbrella.proxy.wait_for_setup"
wait_for_setup()

local log_timing_id = ngx.var.x_api_umbrella_request_id .. "_upstream_response_time"
ngx.shared.logs:set(log_timing_id, "pending", 300)
