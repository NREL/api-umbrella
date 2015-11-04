local cjson = require "cjson"
local http = require "resty.http"
local log_utils = require "api-umbrella.proxy.log_utils"
local logger = require "resty.logger.socket"
local sha256 = require "resty.sha256"
local str = require "resty.string"
local user_agent_parser = require "api-umbrella.proxy.user_agent_parser"
local utils = require "api-umbrella.proxy.utils"

if log_utils.ignore_request() then
  return
end

local ngx_ctx = ngx.ctx
local ngx_var = ngx.var

-- Cache the last geocoded location for each city in a separate index. When
-- faceting by city names on the log index (for displaying on a map), there
-- doesn't appear to be an easy way to fetch the associated locations for each
-- city facet. This allows us to perform a separate lookup to fetch the
-- pre-geocoded locations for each city.
--
-- The geoip stuff actually returns different geocodes for different parts of
-- cities. This approach rolls up each city to the last geocoded location
-- within that city, so it's not perfect, but for now it'll do.
local function cache_city_geocode(premature, id, data)
  if premature then
    return
  end

  local id_hash = sha256:new()
  id_hash:update(id)
  id_hash = id_hash:final()
  id_hash = str.to_hex(id_hash)
  local record = {
    country = data["request_ip_country"],
    region = data["request_ip_region"],
    city = data["request_ip_city"],
    location = data["request_ip_location"],
    updated_at = utils.round(ngx.now() * 1000),
  };

  local elasticsearch_host = config["elasticsearch"]["hosts"][1]
  local index = "api-umbrella"
  local index_type = "city"
  local httpc = http.new()
  local res, err = httpc:request_uri(elasticsearch_host .. "/" .. index .. "/" .. index_type .. "/" .. id_hash, {
    method = "PUT",
    body = cjson.encode(record),
  })
  if err or (res and res.status >= 400) then
    ngx.log(ngx.ERR, "failed to cache city location in elasticsearch: ", err)
  end
end

local function cache_new_city_geocode(data)
  local id = (data["request_ip_country"] or "") .. "-" .. (data["request_ip_region"] or "") .. "-" .. (data["request_ip_city"] or "")

  -- Only cache the first city location per startup to prevent lots of indexing
  -- churn re-indexing the same city.
  if not ngx.shared.geocode_city_cache:get(id) then
    ngx.shared.geocode_city_cache:set(id, true)

    -- Perform the actual cache call in a timer because the http library isn't
    -- supported directly in the log_by_lua context.
    ngx.timer.at(0, cache_city_geocode, id, data)
  end
end

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
    request_at = (ngx_var.msec - (tonumber(ngx_var.request_time) or 0)),
    request_basic_auth_username = ngx_var.remote_user,
    request_connection = request_headers["connection"],
    request_content_type = request_headers["content-type"],
    request_host = request_headers["host"],
    request_ip = ngx_var.remote_addr,
    request_ip_country = ngx_var.geoip_country,
    request_ip_region = ngx_var.geoip_region,
    request_ip_city = ngx_var.geoip_city,
    request_method = ngx_var.request_method,
    request_origin = request_headers["origin"],
    request_referer = request_headers["referer"],
    request_scheme = ngx_var.real_scheme,
    request_size = tonumber(ngx_var.request_length),
    request_user_agent = request_headers["user-agent"],
    response_age = tonumber(response_headers["age"]),
    response_cache = response_headers["x-cache"],
    response_content_encoding = response_headers["content-encoding"],
    response_content_length = tonumber(response_headers["content-length"]),
    response_content_type = response_headers["content-type"],
    response_server = ngx_var.upstream_http_server,
    response_size = tonumber(ngx_var.bytes_sent),
    response_status = tonumber(ngx_var.status),
    response_time = tonumber(ngx_var.request_time),
    gatekeeper_denied_code = ngx_ctx.gatekeeper_denied_code,
    internal_gatekeeper_time = ngx_ctx.internal_overhead,
    response_transfer_encoding = response_headers["transfer-encoding"],
    user_id = ngx_ctx.user_id,
    user_email = ngx_ctx.user_email,
    user_registration_source = ngx_ctx.user_registration_source,
  }

  -- Check for log data set by the separate api backend proxy
  -- (log_api_backend_proxy.lua). This is used for timing information.
  local log_timing_id = id .. "_upstream_response_time"
  local backend_response_time = ngx.shared.logs:get(log_timing_id)
  if backend_response_time then
    data["backend_response_time"] = backend_response_time

    -- Try to determine the overhead API Umbrella incurred on the request.
    -- First we compare the upstream times from this initial proxy to the
    -- backend api router proxy. Note that we don't use the "request_time"
    -- variables, since that could be affected by slow clients.
    data["proxy_overhead"] = (tonumber(ngx_var.upstream_response_time) or 0) - backend_response_time

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

  -- Set the various URL fields.
  log_utils.set_url_fields(data)

  -- Compute the request_hierarchy field.
  log_utils.set_request_hierarchy(data)

  if request_headers["user-agent"] then
    local user_agent_data = user_agent_parser(request_headers["user-agent"])
    if user_agent_data then
      data["request_user_agent_family"] = user_agent_data["family"]
      data["request_user_agent_type"] = user_agent_data["type"]
    end
  end

  local geoip_latitude = ngx_var.geoip_latitude
  if geoip_latitude then
    data["request_ip_location"] = {
      lat = tonumber(geoip_latitude),
      lon = tonumber(ngx_var.geoip_longitude),
    }
  end

  local _, err = logger.log(cjson.encode(data) .. "\n")
  if err then
    ngx.log(ngx.ERR, "failed to log message: ", err)
    return
  end

  if backend_response_time then
    ngx.shared.logs:delete(log_timing_id)
  end

  if data["request_ip_location"] then
    cache_new_city_geocode(data)
  end
end

local ok, err = pcall(log_request)
if not ok then
  ngx.log(ngx.ERR, "failed to log request: ", err)
end
