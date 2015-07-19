local start_time = ngx.now()

local api_matcher = require "api-umbrella.proxy.middleware.api_matcher"
local error_handler = require "api-umbrella.proxy.error_handler"
local host_strip_port = require "api-umbrella.utils.host_strip_port"
local httpsify_current_url = require "api-umbrella.utils.httpsify_current_url"
local utils = require "api-umbrella.proxy.utils"
local inspect = require "inspect"
local plutils = require "pl.utils"

local get_packed = utils.get_packed
local ngx_var = ngx.var

-- Cache various "ngx.var" lookups that are repeated throughout the stack,
-- so they don't allocate duplicate memory during the request, and since
-- ngx.var lookups are apparently somewhat expensive.
ngx.ctx.args = ngx_var.args
ngx.ctx.arg_api_key = ngx_var.arg_api_key
ngx.ctx.host = ngx_var.http_x_forwarded_host or ngx_var.http_host or ngx_var.host
ngx.ctx.host_no_port = host_strip_port(ngx.ctx.host)
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

local hostname_searches = {}
local hostname = host_strip_port(ngx.ctx.host)
local hostname_parts = plutils.split(hostname, ".", true)
for index, _ in ipairs(hostname_parts) do
  local parents_and_self = {}
  for i = index, #hostname_parts do
    table.insert(parents_and_self, hostname_parts[i])
  end

  local base = table.concat(parents_and_self, ".")
  if index == 1 then
    table.insert(hostname_searches, base)
  else
    table.insert(hostname_searches, "*." .. base)
  end

  table.insert(hostname_searches, "." .. base)
end

if hostname == "localhost" then
  table.insert(hostname_searches, "127.0.0.1")
elseif hostname == "127.0.0.1" then
  table.insert(hostname_searches, "localhost")
end

table.insert(hostname_searches, "*")

if config["_default_hostname"] then
  table.insert(hostname_searches, config["_default_hostname"])
end

ngx.ctx.hostname_searches = hostname_searches

local data = get_packed(ngx.shared.apis, "packed_data") or {}
if data["hosts_by_name"] then
  for _, search in ipairs(hostname_searches) do
    if data["hosts_by_name"][search] then
      matched_host = data["hosts_by_name"][search]
      break
    end
  end
end

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
      local match, err = ngx.re.match(ngx.ctx.original_uri, matched_host["website_backend_required_https_regex"], "ijo")
      if match then
        return ngx.redirect(httpsify_current_url(), ngx.HTTP_MOVED_PERMANENTLY)
      end
    end

    ngx.var.api_umbrella_proxy_pass = matched_host["website_protocol"] .. "://" .. matched_host["server_host"] .. ":" .. matched_host["server_port"]
    return true
  end

  return error_handler(err)
end

-- Compute how much time we spent in Lua processing during this phase of the
-- request.
utils.overhead_timer(start_time)
