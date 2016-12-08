local log_utils = require "api-umbrella.proxy.log_utils"

if log_utils.ignore_request() then
  return
end

local ngx_var = ngx.var
local log_timing_id = ngx_var.x_api_umbrella_request_id .. "_upstream_response_time"
local upstream_response_time = tonumber(ngx_var.upstream_response_time)
if upstream_response_time then
  if config["app_env"] == "test" and ngx.var.http_x_api_umbrella_test_simulate_out_of_order_logging == "true" then
    -- For the test environment, simulate the rare case where the initial
    -- proxy's logging occurs before this backend proxy's logging.
    --
    -- This is important to test, since log_initial_proxy.lua's behavior
    -- changes when this edge case is hit, and we continue logging inside a
    -- timer callback. Since not all nginx variables are available in the timer
    -- context, we want to make sure we can reliably test this scenario and
    -- ensure that code-path works (rather than it being rare and hard to
    -- reproduce in the test suite).
    local function set_fake_delayed_response_time()
      ngx.shared.logs:set(log_timing_id, 99, 60)
    end
    ngx.timer.at(0.2, set_fake_delayed_response_time)
  else
    ngx.shared.logs:set(log_timing_id, upstream_response_time, 60)
  end
end
