local cjson = require "cjson"
local inspect = require "inspect"
local utf8 = require "lua-utf8"
local log_utils = require "log_utils"
local logger = require "resty.logger.socket"
local utils = require "utils"
local user_agent_parser = require "user_agent_parser"

if log_utils.ignore_request() then
  return
end

local ngx_ctx = ngx.ctx
local ngx_var = ngx.var

local function log_request()
  -- Init the resty logger socket.
  if not logger.initted() then
    local ok, err = logger.init{
      host = config["heka"]["host"],
      port = config["heka"]["port"],
      flush_limit = 4096, -- 4KB
      drop_limit = 10485760, -- 10MB
      periodic_flush = 0.1,
    }

    if not ok then
      ngx.log(ngx.ERR, "failed to initialize the logger: ", err)
      return
    end
  end

  -- Fetch all the request and response headers.
  local request_headers = ngx.req.get_headers();
  local response_headers = ngx.resp.get_headers();

  -- Put together the basic log data.
  local id = ngx_var.x_api_umbrella_request_id
  local data = {
    id = id,
    api_key = ngx_ctx.api_key,
    request_accept = request_headers["accept"],
    request_accept_encoding = request_headers["accept-encoding"],
    request_at = (ngx_var.msec - tonumber(ngx_var.request_time)),
    request_basic_auth_username = ngx_var.remote_user,
    request_connection = request_headers["connection"],
    request_content_type = request_headers["content-type"],
    request_host = request_headers["host"],
    request_ip = ngx_var.remote_addr,
    request_method = ngx_var.request_method,
    request_origin = request_headers["origin"],
    request_path = ngx_ctx.uri,
    request_referer = request_headers["referer"],
    request_scheme = ngx_var.real_scheme,
    request_size = tonumber(ngx_var.request_length),
    request_user_agent = request_headers["user-agent"],
    response_age = tonumber(response_headers["age"]),
    response_content_encoding = response_headers["content-encoding"],
    response_content_length = tonumber(response_headers["Content-Length"]),
    response_content_type = response_headers["Content-Type"],
    response_server = ngx_var.upstream_http_server,
    response_size = tonumber(ngx_var.bytes_sent),
    response_status = tonumber(ngx_var.status),
    response_time = tonumber(ngx_var.request_time),
    gatekeeper_denied_code = ngx_ctx.gatekeeper_denied_code,
    internal_gatekeeper_time = ngx_ctx.internal_overhead,
    response_transfer_encoding = response_headers["Transfer-Encoding"],
    user_id = ngx_ctx.user_id,
    user_email = ngx_ctx.user_email,
    user_registration_source = ngx_ctx.user_registration_source,
  }

  -- Check for log data set by the separate api backend proxy
  -- (log_api_backend_proxy.lua). This is used for timing information.
  local backend_response_time = ngx.shared.logs:get(id .. "_upstream_response_time")
  if backend_response_time then
    data["backend_response_time"] = backend_response_time

    -- Try to determine the overhead API Umbrella incurred on the request.
    -- First we compare the upstream times from this initial proxy to the
    -- backend api router proxy. Note that we don't use the "request_time"
    -- variables, since that could be affected by slow clients.
    data["proxy_overhead"] = tonumber(ngx_var.upstream_response_time) - backend_response_time

    -- Since we're using the upstream response times for determining overhead,
    -- next add in the amount of time we've calculated that we've used
    -- internally in the Lua code.
    --
    -- Note: Due to how openresty caches the ngx.now() calls (unless we call
    -- ngx.update_time, which we don't want to do on every request), this timer
    -- will be very approximate, but we mainly want this for detecting if
    -- things really start to increase dramatically.
    if ngx_ctx.internal_overhead then
      data["proxy_overhead"] = data["proxy_overhead"] + ngx_ctx.internal_overhead
    end
  end

  if not data["proxy_overhead"] then
    data["proxy_overhead"] = ngx_ctx.internal_overhead
  end

  -- Turn any internal fields from seconds (with millisecond precision
  -- decimals) into milliseconds.
  for _, msec_field in ipairs(log_utils.MSEC_FIELDS) do
    if data[msec_field] then
      -- Round the results after turning into milliseconds. Since all the nginx
      -- timers only have millisecond precision, any decimals left after
      -- converting are just an artifact of the original float storage or math
      -- (eg, 1.00001... or 1.999988..).
      data[msec_field] = utils.round(data[msec_field] * 1000)
    end
  end

  -- Compute the request_hierarchy field.
  log_utils.set_request_hierarchy(data)

  -- Set the various URL fields.
  log_utils.set_url_fields(data)

  if request_headers["user-agent"] then
    local user_agent_data = user_agent_parser(request_headers["user-agent"])
    if user_agent_data then
      data["request_user_agent_family"] = user_agent_data["family"]
      data["request_user_agent_type"] = user_agent_data["type"]
    end
  end

  local bytes, err = logger.log(cjson.encode(data) .. "\n")
  if err then
    ngx.log(ngx.ERR, "failed to log message: ", err)
    return
  end

  ngx.shared.logs:delete(id)
end

local ok, err = pcall(log_request)
if not ok then
  ngx.log(ngx.ERR, "failed to log request: ", err)
end
