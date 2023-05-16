local flatten_headers = require "api-umbrella.utils.flatten_headers"
local log_utils = require "api-umbrella.proxy.log_utils"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local ngx_ctx = ngx.ctx
local ngx_var = ngx.var

if log_utils.ignore_request(ngx_ctx) then
  return
end

local sec_to_ms = log_utils.sec_to_ms

local function build_log_data()
  -- Fetch all the request and response headers.
  local request_headers = flatten_headers(ngx.req.get_headers());
  local response_headers = flatten_headers(ngx.resp.get_headers());

  -- Put together the basic log data.
  local id = ngx_var.x_api_umbrella_request_id
  local data = {
    backend_resolved_host = response_headers["x-api-umbrella-backend-resolved-host"],
    backend_response_code_details = response_headers["x-api-umbrella-backend-response-code-details"],
    backend_response_flags = response_headers["x-api-umbrella-backend-response-flags"],
    denied_reason = ngx_ctx.gatekeeper_denied_code,
    id = id,
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
    response_custom1 = response_headers["x-api-umbrella-analytics-custom1"],
    response_custom2 = response_headers["x-api-umbrella-analytics-custom2"],
    response_custom3 = response_headers["x-api-umbrella-analytics-custom3"],
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

  log_utils.set_request_ip_geo_fields(data, ngx_var)
  log_utils.set_computed_timestamp_fields(data)
  log_utils.set_computed_url_fields(data, ngx_ctx)
  log_utils.set_computed_user_agent_fields(data)

  return log_utils.normalized_data(data)
end

local function log_request()
  -- Build the log message and send to rsyslog for processing.
  local data = build_log_data()
  local syslog_message = log_utils.build_syslog_message(data)
  local _, err = log_utils.send_syslog_message(syslog_message)
  if err then
    ngx.log(ngx.ERR, "failed to log message: ", err)
    return
  end

  -- After logging, cache any new cities we see from GeoIP in our database.
  if data["request_ip_lat"] then
    log_utils.cache_new_city_geocode(data)
  end
end

local ok, err = xpcall(log_request, xpcall_error_handler)
if not ok then
  ngx.log(ngx.ERR, "failed to log request: ", err)
end
