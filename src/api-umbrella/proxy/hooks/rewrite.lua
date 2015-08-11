local start_time = ngx.now()

local api_matcher = require "api-umbrella.proxy.middleware.api_matcher"
local error_handler = require "api-umbrella.proxy.error_handler"
local host_normalize = require "api-umbrella.utils.host_normalize"
local httpsify_current_url = require "api-umbrella.utils.httpsify_current_url"
local utils = require "api-umbrella.proxy.utils"
local inspect = require "inspect"
local plutils = require "pl.utils"
local wait_for_setup = require "api-umbrella.proxy.wait_for_setup"

local get_packed = utils.get_packed
local ngx_var = ngx.var

wait_for_setup()

-- Cache various "ngx.var" lookups that are repeated throughout the stack,
-- so they don't allocate duplicate memory during the request, and since
-- ngx.var lookups are apparently somewhat expensive.
ngx.ctx.args = ngx_var.args
ngx.ctx.arg_api_key = ngx_var.arg_api_key
ngx.ctx.host = ngx_var.http_x_forwarded_host or ngx_var.http_host or ngx_var.host
ngx.ctx.host_normalized = host_normalize(ngx.ctx.host)
ngx.ctx.http_x_api_key = ngx_var.http_x_api_key
ngx.ctx.port = ngx_var.http_x_forwarded_port or ngx_var.server_port
ngx.ctx.protocol = ngx_var.http_x_forwarded_proto or ngx_var.scheme
ngx.ctx.remote_addr = ngx_var.remote_addr
ngx.ctx.remote_user = ngx_var.remote_user
ngx.ctx.request_method = string.lower(ngx.var.request_method)
ngx.ctx.original_request_uri = ngx_var.request_uri
ngx.ctx.request_uri = ngx.ctx.original_request_uri
ngx.ctx.original_uri = ngx_var.uri
ngx.ctx.uri = ngx.ctx.original_uri

local matched_host
local default_host
local data = get_packed(ngx.shared.active_config, "packed_data") or {}
if data["hosts"] then
  for _, host in ipairs(data["hosts"]) do
    if host["_hostname_normalized"] == "*" and default_host then
      matched_host = default_host
      break
    elseif host["_hostname_wildcard_regex"] then
      local match, err = ngx.re.match(ngx.ctx.host_normalized, host["_hostname_wildcard_regex"], "jo")
      if match then
        matched_host = host
        break
      end
    else
      if ngx.ctx.host_normalized == host["_hostname_normalized"] then
        matched_host = host
        break
      end
    end

    if host["default"] and not default_host then
      default_host = host
    end
  end
end

if not matched_host and default_host then
  matched_host = default_host
end
ngx.ctx.matched_host = matched_host

if matched_host and matched_host["_web_backend?"] then
  local match, err = ngx.re.match(ngx.ctx.original_uri, config["router"]["web_backend_regex"], "ijo")
  if match then
    local protocol = ngx.ctx.protocol
    if protocol ~= "https" then
      local match, err = ngx.re.match(ngx.ctx.original_uri, config["router"]["web_backend_required_https_regex"], "ijo")
      if match then
        return ngx.redirect(httpsify_current_url(), ngx.HTTP_MOVED_PERMANENTLY)
      end
    end

    ngx.var.api_umbrella_proxy_pass = "http://api_umbrella_web_backend"
    return true
  end
end

local api, err = api_matcher()
if api then
  ngx.ctx.matched_api = api
  ngx.var.api_umbrella_proxy_pass = "http://api_umbrella_trafficserver_backend"
else
  if matched_host and matched_host["_website_backend?"] then
    local protocol = ngx.ctx.protocol
    if protocol ~= "https" then
      local match, err = ngx.re.match(ngx.ctx.original_uri, matched_host["_website_backend_required_https_regex"], "ijo")
      if match then
        return ngx.redirect(httpsify_current_url(), ngx.HTTP_MOVED_PERMANENTLY)
      end
    end

    ngx.var.api_umbrella_proxy_pass = matched_host["_website_protocol"] .. "://" .. matched_host["_website_server_host"] .. ":" .. matched_host["_website_server_port"]
    return true
  end

  return error_handler(err)
end

-- Compute how much time we spent in Lua processing during this phase of the
-- request.
utils.overhead_timer(start_time)
