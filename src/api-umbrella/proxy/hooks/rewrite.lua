local api_matcher = require "api-umbrella.proxy.middleware.api_matcher"
local error_handler = require "api-umbrella.proxy.error_handler"
local host_normalize = require "api-umbrella.utils.host_normalize"
local redirect_matches_to_https = require "api-umbrella.utils.redirect_matches_to_https"
local utils = require "api-umbrella.proxy.utils"
local website_matcher = require "api-umbrella.proxy.middleware.website_matcher"

local get_packed = utils.get_packed
local ngx_var = ngx.var

-- Cache various "ngx.var" lookups that are repeated throughout the stack,
-- so they don't allocate duplicate memory during the request, and since
-- ngx.var lookups are apparently somewhat expensive.
ngx.ctx.args = ngx_var.args
ngx.ctx.arg_api_key = ngx_var.arg_api_key
if(config["router"]["match_x_forwarded_host"]) then
  ngx.ctx.host = ngx_var.http_x_forwarded_host or ngx_var.http_host or ngx_var.host
else
  ngx.ctx.host = ngx_var.http_host or ngx_var.host
end
ngx.ctx.host_normalized = host_normalize(ngx.ctx.host)
ngx.ctx.http_x_api_key = ngx_var.http_x_api_key
ngx.ctx.port = ngx_var.real_port
ngx.ctx.protocol = ngx_var.real_scheme
ngx.ctx.remote_addr = ngx_var.remote_addr
ngx.ctx.remote_user = ngx_var.remote_user
ngx.ctx.request_method = string.lower(ngx.var.request_method)
ngx.ctx.original_request_uri = ngx_var.request_uri
ngx.ctx.request_uri = ngx.ctx.original_request_uri
ngx.ctx.original_uri = ngx_var.uri
ngx.ctx.uri = ngx.ctx.original_uri

local function route_to_api(api, url_match)
  ngx.ctx.matched_api = api
  ngx.ctx.matched_api_url_match = url_match
end

local function route_to_website(website)
  redirect_matches_to_https(website["website_backend_required_https_regex"] or config["router"]["website_backend_required_https_regex_default"])
  if website["backend_host"] then
    ngx.var.proxy_host_header = website["backend_host"]
  end

  ngx.req.set_header("X-Api-Umbrella-Backend-Server-Scheme", website["backend_protocol"] or "http")
  ngx.req.set_header("X-Api-Umbrella-Backend-Server-Host", website["server_host"])
  ngx.req.set_header("X-Api-Umbrella-Backend-Server-Port", website["server_port"])
end

local active_config = get_packed(ngx.shared.active_config, "packed_data") or {}

local api, url_match, api_err = api_matcher(active_config)
if api and url_match then
  route_to_api(api, url_match)
elseif api_err == "not_found" then
  local website, website_err = website_matcher(active_config)
  if website then
    route_to_website(website)
  else
    error_handler(website_err)
  end
else
  error_handler(api_err)
end
