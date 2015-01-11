local api_key_validator = require "api_key_validator"
local api_matcher = require "api_matcher"
local api_settings = require "api_settings"
local error_handler = require "error_handler"
local ip_validator = require "ip_validator"
local rate_limit = require "rate_limit"
local referer_validator = require "referer_validator"
local rewrite_request = require "rewrite_request"
local role_validator = require "role_validator"
local user_settings = require "user_settings"

local ngx_var = ngx.var

-- Cache various "ngx.var" lookups that are repeated throughout the stack,
-- so they don't allocate duplicate memory during the request, and since
-- ngx.var lookups are apparently somewhat expensive.
ngx.ctx.arg_api_key = ngx_var.arg_api_key
ngx.ctx.host = ngx_var.http_x_forwarded_host or ngx_var.host
ngx.ctx.http_x_api_key = ngx_var.http_x_api_key
ngx.ctx.port = ngx_var.http_x_forwarded_port or ngx_var.server_port
ngx.ctx.protocol = ngx_var.http_x_forwarded_proto or ngx_var.scheme
ngx.ctx.remote_addr = ngx_var.remote_addr
ngx.ctx.remote_user = ngx_var.remote_user
ngx.ctx.uri = ngx_var.uri

-- Try to find the matching API backend first, since it dictates further
-- settings and requirements.
local api, url_match, err = api_matcher()
if err then
  return error_handler(err)
end

-- Fetch the settings from the matched API.
local settings, err = api_settings(api)
if err then
  return error_handler(err)
end

-- Validate the API key that's passed in, if this API requires API keys.
local user, err = api_key_validator(settings)
if err then
  return error_handler(err)
end

-- Fetch and merge any user-specific settings.
local err = user_settings(settings, user)
if err then
  return error_handler(err)
end

-- If this API requires roles, verify that the user has those.
local err = role_validator(settings, user)
if err then
  return error_handler(err)
end

-- If this API or user requires the traffic come from certain IP addresses,
-- verify those.
local err = ip_validator(settings, user)
if err then
  return error_handler(err)
end

-- If this API or user requires the traffic come from certain HTTP referers,
-- verify those.
local err = referer_validator(settings, user)
if err then
  return error_handler(err)
end

-- If we've gotten this far, it means the user is authorized to access this
-- API, so apply the rate limits for this user and API.
local err = rate_limit(settings, user)
if err then
  return error_handler(err)
end

-- Perform any request rewriting.
local err = rewrite_request(user, api, settings)
if err then
  return error_handler(err)
end
