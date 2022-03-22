local api_matcher = require "api-umbrella.proxy.middleware.api_matcher"
local config = require "api-umbrella.proxy.models.file_config"
local error_handler = require "api-umbrella.proxy.error_handler"
local escape_uri_non_ascii = require "api-umbrella.utils.escape_uri_non_ascii"
local host_normalize = require "api-umbrella.utils.host_normalize"
local packed_shared_dict = require "api-umbrella.utils.packed_shared_dict"
local redirect_matches_to_https = require "api-umbrella.utils.redirect_matches_to_https"
local website_matcher = require "api-umbrella.proxy.middleware.website_matcher"

local get_packed = packed_shared_dict.get_packed
local ngx_var = ngx.var

-- Determine the protocol/scheme and port this connection represents, based on
-- forwarded info or override config.
local http_port = tostring(config["http_port"])
local https_port = tostring(config["https_port"])
local server_port = ngx_var.server_port
local scheme = ngx_var.scheme
local forwarded_protocol = ngx_var.http_x_forwarded_proto
local forwarded_port = ngx_var.http_x_forwarded_port
local real_proto
local real_port
if server_port == https_port then
  real_proto = config["override_public_https_proto"] or forwarded_protocol or scheme
  real_port = config["override_public_https_port"] or forwarded_port or https_port
elseif server_port == http_port then
  real_proto = config["override_public_http_proto"] or forwarded_protocol or scheme
  real_port = config["override_public_http_port"] or forwarded_port or http_port
else
  real_proto = forwarded_protocol or scheme
  real_port = forwarded_port or http_port
end

-- Determine the host, based on forwarded information.
local real_host
if config["router"]["match_x_forwarded_host"] then
  real_host = ngx_var.http_x_forwarded_host
end
if not real_host then
  real_host = ngx_var.http_host or ngx_var.host
end

-- Append the port to the host header.
--
-- When the port is overriden, always append it to the host header (replacing
-- any existing values). In other situations, only append the port if it's a
-- non-default port (not 80 or 443) and the host header doesn't already contain
-- a port.
if real_proto == "http" and config["override_public_http_port"] then
  real_host = ngx.re.sub(real_host, "(:.*$|$)", ":" .. config["override_public_http_port"], "jo")
elseif real_proto == "https" and config["override_public_https_port"] then
  real_host = ngx.re.sub(real_host, "(:.*$|$)", ":" .. config["override_public_https_port"], "jo")
elseif not ngx.re.find(real_host, ":", "jo") then
  if not (real_proto == "http" and real_port == "80") or not (real_proto == "https" and real_port == "443") then
    real_host = real_host .. ":" .. real_port
  end
end

-- Cache various "ngx.var" lookups that are repeated throughout the stack,
-- so they don't allocate duplicate memory during the request, and since
-- ngx.var lookups are apparently somewhat expensive.
ngx.ctx.arg_api_key = ngx_var.arg_api_key
ngx.ctx.host = real_host
ngx.ctx.host_normalized = host_normalize(real_host)
ngx.ctx.http_x_api_key = ngx_var.http_x_api_key
ngx.ctx.port = real_port
ngx.ctx.protocol = real_proto
ngx.ctx.remote_addr = ngx_var.remote_addr
ngx.ctx.remote_user = ngx_var.remote_user
ngx.ctx.request_method = string.lower(ngx.var.request_method)

local args = ngx_var.args
if args then
  args = escape_uri_non_ascii(args)
end
ngx.ctx.args = args

local request_uri = ngx_var.request_uri
ngx.ctx.original_request_uri = request_uri
ngx.ctx.request_uri = request_uri

local uri_path = ngx_var.uri
ngx.ctx.original_uri_path = uri_path
ngx.ctx.uri_path = uri_path

local function route()
  ngx.var.proxy_host_header = ngx.ctx.proxy_host

  -- For cache key purposes, allow HEAD requests to re-use the cache key for
  -- GET requests (since HEAD queries can be answered from cached GET data).
  -- But since HEAD requests by themselves aren't cacheable, we don't have to
  -- worry about GET requests re-using the HEAD response.
  local cache_request_method = ngx.ctx.request_method
  if cache_request_method == "head" then
    cache_request_method = "get"
  end

  ngx.req.set_header("X-Api-Umbrella-Backend-Host", ngx.ctx.backend_host)
  ngx.req.set_header("X-Api-Umbrella-Cache-Request-Method", cache_request_method)
  ngx.req.set_header("X-Forwarded-Proto", ngx.ctx.protocol)
  ngx.req.set_header("X-Forwarded-Port", ngx.ctx.port)
end

local function route_to_api(api, url_match)
  redirect_matches_to_https(config["router"]["api_backend_required_https_regex_default"])

  ngx.ctx.matched_api = api
  ngx.ctx.matched_api_url_match = url_match
  ngx.ctx.proxy_host = "api-backend-" .. api["id"]

  route()
end

local function route_to_website(website)
  redirect_matches_to_https(website["website_backend_required_https_regex"] or config["router"]["website_backend_required_https_regex_default"])

  ngx.ctx.proxy_host = "website-backend-" .. website["id"]
  ngx.ctx.backend_host = website["backend_host"] or ngx.ctx.host

  route()
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
