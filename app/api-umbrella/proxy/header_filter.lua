local start_time = ngx.now()
local rewrite_response = require "api-umbrella.proxy.rewrite_response"
local utils = require "api-umbrella.proxy.utils"

local settings = ngx.ctx.settings

-- Perform any response rewriting.
local err = rewrite_response(settings)
if err then
  return error_handler(err, settings)
end

-- Compute how much time we spent in Lua processing during this phase of the
-- request.
utils.overhead_timer(start_time)
