local active_config_store = require("api-umbrella.proxy.stores.active_config_store")
local api_matcher = require "api-umbrella.proxy.middleware.api_matcher"
local config = require("api-umbrella.utils.load_config")()
local error_handler = require "api-umbrella.proxy.error_handler"
local escape_uri_non_ascii = require "api-umbrella.utils.escape_uri_non_ascii"
local host_normalize = require "api-umbrella.utils.host_normalize"
local redirect_matches_to_https = require "api-umbrella.utils.redirect_matches_to_https"
local website_matcher = require "api-umbrella.proxy.middleware.website_matcher"

local get_active_config = active_config_store.get
local ngx_ctx = ngx.ctx
local ngx_var = ngx.var
local refresh_local_active_config_cache = active_config_store.refresh_local_cache
local re_find = ngx.re.find
local re_sub = ngx.re.sub
local req_set_header = ngx.req.set_header

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
  real_host = re_sub(real_host, "(:.*$|$)", ":" .. config["override_public_http_port"], "jo")
elseif real_proto == "https" and config["override_public_https_port"] then
  real_host = re_sub(real_host, "(:.*$|$)", ":" .. config["override_public_https_port"], "jo")
elseif not re_find(real_host, ":", "jo") then
  if not (real_proto == "http" and real_port == "80") or not (real_proto == "https" and real_port == "443") then
    real_host = real_host .. ":" .. real_port
  end
end

-- Cache various "ngx.var" lookups that are repeated throughout the stack,
-- so they don't allocate duplicate memory during the request, and since
-- ngx.var lookups are apparently somewhat expensive.
ngx_ctx.arg_api_key = ngx_var.arg_api_key
ngx_ctx.host = real_host
ngx_ctx.host_normalized = host_normalize(real_host)
ngx_ctx.http_x_api_key = ngx_var.http_x_api_key
ngx_ctx.port = real_port
ngx_ctx.protocol = real_proto
ngx_ctx.remote_addr = ngx_var.remote_addr
ngx_ctx.remote_user = ngx_var.remote_user
ngx_ctx.request_method = string.lower(ngx_var.request_method)

local args = ngx_var.args
if args then
  args = escape_uri_non_ascii(args)
end
ngx_ctx.args = args

local request_uri = ngx_var.request_uri
ngx_ctx.original_request_uri = request_uri
ngx_ctx.request_uri = request_uri

local uri_path = ngx_var.uri
ngx_ctx.original_uri_path = uri_path
ngx_ctx.uri_path = uri_path

local function route()
  ngx_var.proxy_host_header = ngx_ctx.proxy_host

  -- For cache key purposes, allow HEAD requests to re-use the cache key for
  -- GET requests (since HEAD queries can be answered from cached GET data).
  -- But since HEAD requests by themselves aren't cacheable, we don't have to
  -- worry about GET requests re-using the HEAD response.
  local cache_request_method = ngx_ctx.request_method
  if cache_request_method == "head" then
    cache_request_method = "get"
  end

  req_set_header("X-Api-Umbrella-Backend-Host", ngx_ctx.backend_host)
  req_set_header("X-Api-Umbrella-Cache-Request-Method", cache_request_method)
  req_set_header("X-Forwarded-Proto", ngx_ctx.protocol)
  req_set_header("X-Forwarded-Port", ngx_ctx.port)
end

local function route_to_api(api, url_match)
  redirect_matches_to_https(ngx_ctx, config["router"]["api_backend_required_https_regex_default"])

  ngx_ctx.matched_api = api
  ngx_ctx.matched_api_url_match = url_match
  ngx_ctx.proxy_host = "api-backend-" .. api["id"]

  route()
end

local function route_to_website(website)
  redirect_matches_to_https(ngx_ctx, website["website_backend_required_https_regex"] or config["router"]["website_backend_required_https_regex_default"])

  ngx_ctx.proxy_host = "website-backend-" .. website["id"]
  ngx_ctx.backend_host = website["backend_host"] or ngx_ctx.host

  route()
end

-- Normally, the active_config_store_refresh_local_cache job will
-- asynchronously update local caches so the local caches across workers will
-- become eventually consistent. But if set to 0 (particularly for the test
-- environment), then allow for refreshing the cache on every request so that
-- changes are always live at the same time across workers.
if config["router"]["active_config"]["refresh_local_cache_interval"] == 0 then
  refresh_local_active_config_cache()
end

local active_config = get_active_config()

local api, url_match, api_err = api_matcher(ngx_ctx, active_config)
if api and url_match then
  route_to_api(api, url_match)
elseif api_err == "not_found" then
  local website, website_err = website_matcher(ngx_ctx, active_config)
  if website then
    route_to_website(website)
  else
    error_handler(ngx_ctx, website_err)
  end
else
  error_handler(ngx_ctx, api_err)
end
