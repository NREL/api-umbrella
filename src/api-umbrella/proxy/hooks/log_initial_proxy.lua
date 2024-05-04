local log_utils = require "api-umbrella.proxy.log_utils"
local utf8_clean = require("lua-utf8").clean

local ignore_request = log_utils.ignore_request
local ngx_ctx = ngx.ctx

if ignore_request(ngx_ctx) then
  return
end

local flatten_headers = require "api-umbrella.utils.flatten_headers"
local json_encode = require "api-umbrella.utils.json_encode"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local cache_new_city_geocode = log_utils.cache_new_city_geocode
local ngx_var = ngx.var
local normalized_data = log_utils.normalized_data
local req_get_headers = ngx.req.get_headers
local resp_get_headers = ngx.resp.get_headers
local sec_to_ms = log_utils.sec_to_ms
local send_message = log_utils.send_message
local set_computed_url_fields = log_utils.set_computed_url_fields
local set_computed_user_agent_fields = log_utils.set_computed_user_agent_fields
local set_request_ip_geo_fields = log_utils.set_request_ip_geo_fields

local function build_log_data()
  -- Fetch all the request and response headers.
  local request_headers = flatten_headers(req_get_headers());
  local response_headers = flatten_headers(resp_get_headers());

  -- Put together the basic log data.
  local request_id = ngx_var.x_api_umbrella_request_id
  local data = {
    api_backend_resolved_host = ngx_ctx.x_api_umbrella_backend_resolved_host,
    api_backend_response_code_details = ngx_ctx.x_api_umbrella_backend_response_code_details,
    api_backend_response_flags = ngx_ctx.x_api_umbrella_backend_response_flags,
    gatekeeper_denied_code = ngx_ctx.gatekeeper_denied_code,
    request_id = request_id,
    request_accept = request_headers["accept"],
    request_accept_encoding = request_headers["accept-encoding"],
    request_basic_auth_username = ngx_var.remote_user,
    request_connection = request_headers["connection"],
    request_content_type = request_headers["content-type"],
    request_ip = ngx_ctx.remote_addr or ngx_var.remote_addr,
    request_method = ngx_var.request_method,
    request_origin = request_headers["origin"],
    request_referer = request_headers["referer"],
    request_size = ngx_var.request_length,
    request_url_host = request_headers["host"],
    request_url_port = ngx_ctx.port,
    request_url_scheme = ngx_ctx.protocol,
    request_user_agent = request_headers["user-agent"],
    response_age = response_headers["age"],
    response_cache = response_headers["x-cache"],
    response_content_encoding = response_headers["content-encoding"],
    response_content_length = response_headers["content-length"],
    response_content_type = response_headers["content-type"],
    response_custom1 = ngx_ctx.x_api_umbrella_analytics_custom1,
    response_custom2 = ngx_ctx.x_api_umbrella_analytics_custom2,
    response_custom3 = ngx_ctx.x_api_umbrella_analytics_custom3,
    response_server = ngx_var.upstream_http_server,
    response_size = ngx_var.bytes_sent,
    response_status = ngx_var.status,
    response_transfer_encoding = response_headers["transfer-encoding"],
    timer_response = sec_to_ms(ngx_var.request_time),
    timestamp_utc = sec_to_ms(ngx_var.msec),
    user_id = ngx_ctx.user_id,

    -- Deprecated
    legacy_api_key = ngx_ctx.api_key,
    legacy_user_email = ngx_ctx.user_email,
    legacy_user_registration_source = ngx_ctx.user_registration_source,
  }

  if ngx_ctx.matched_api then
    data["api_backend_id"] = ngx_ctx.matched_api["id"]
  end

  if ngx_ctx.matched_api_url_match then
    data["api_backend_url_match_id"] = ngx_ctx.matched_api_url_match["id"]
  end

  -- Extract the Traffic Server codes in the "Via" HTTP header (eg, something
  -- like "cMs f "):
  -- https://docs.trafficserver.apache.org/en/9.1.x/appendices/faq.en.html#how-do-i-interpret-the-via-header-code
  -- Our last layer should always be at the end, even if multiple Via headers
  -- are present.
  local via = response_headers["via"]
  if via then
    data["response_cache_flags"] = string.sub(via, -8, -3)
  end

  set_request_ip_geo_fields(data, ngx_var)
  set_computed_url_fields(data, ngx_ctx)
  set_computed_user_agent_fields(data)

  return data
end

local function log_request()
  -- Build the log message and send to Fluent Bit for processing.
  local data = build_log_data()
  local original_json = json_encode(normalized_data(data))
  local message, was_valid_utf8 = utf8_clean(original_json)
  if not was_valid_utf8 then
    ngx.log(ngx.WARN, "log message contained invalid utf-8, original: ", original_json)
    ngx.log(ngx.WARN, "log message contained invalid utf-8, cleaned: ", message)
  elseif not message then
    ngx.log(ngx.ERR, "failed to log message, message missing: ", original_json)
  end

  if message then
    local _, err = send_message(message)
    if err then
      ngx.log(ngx.ERR, "failed to log message: ", err)
      return
    end
  end

  -- After logging, cache any new cities we see from GeoIP in our database.
  if data["request_ip_lat"] then
    cache_new_city_geocode(data)
  end
end

local ok, err = xpcall(log_request, xpcall_error_handler)
if not ok then
  ngx.log(ngx.ERR, "failed to log request: ", err)
end
