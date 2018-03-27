local error_handler = require "api-umbrella.proxy.error_handler"
local rewrite_response = require "api-umbrella.proxy.middleware.rewrite_response"
local header_based_rate_limiter = require "api-umbrella.proxy.middleware.rate_limit"

local settings = ngx.ctx.settings
local user = ngx.ctx.user

-- ignore any errors because it's too late to do anything
-- The same rate limit module operates based on headers when called
-- in header filter phase

if settings and user then
  header_based_rate_limiter(settings, user)
end

-- Perform any response rewriting.
local err = rewrite_response(settings)
if err then
  return error_handler(err, settings)
end
