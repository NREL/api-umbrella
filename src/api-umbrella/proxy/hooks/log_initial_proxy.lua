local iconv = require "iconv"
local elasticsearch_encode_json = require "api-umbrella.utils.elasticsearch_encode_json"
local flatten_headers = require "api-umbrella.utils.flatten_headers"
local log_utils = require "api-umbrella.proxy.log_utils"
local logger = require "resty.logger.socket"
local luatz = require "luatz"
local mongo = require "api-umbrella.utils.mongo"
local sha256 = require "resty.sha256"
local str = require "resty.string"
local user_agent_parser = require "api-umbrella.proxy.user_agent_parser"
local utils = require "api-umbrella.proxy.utils"

if log_utils.ignore_request() then
  return
end

local truncate_header = log_utils.truncate_header

local ngx_ctx = ngx.ctx
local ngx_var = ngx.var

local syslog_facility = 16 -- local0
local syslog_severity = 6 -- info
local syslog_priority = (syslog_facility * 8) + syslog_severity
local syslog_version = 1

local timezone = luatz.get_tz(config["analytics"]["timezone"])

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
    _id = id_hash,
    country = data["request_ip_country"],
    region = data["request_ip_region"],
    city = data["request_ip_city"],
    location = {
      type = "Point",
      coordinates = {
        data["request_ip_lon"],
        data["request_ip_lat"],
      },
    },
    updated_at = { ["$date"] = { ["$numberLong"] = tostring(ngx.now() * 1000) } },
  }

  local _, err = mongo.update("log_city_locations", record["_id"], record)
  if err then
    ngx.log(ngx.ERR, "failed to cache city location: ", err)
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
      host = config["rsyslog"]["host"],
      port = config["rsyslog"]["port"],
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
  local request_headers = flatten_headers(ngx.req.get_headers());
  local response_headers = flatten_headers(ngx.resp.get_headers());

  -- The GeoIP module returns ISO-8859-1 encoded city names, but we need UTF-8
  -- for inserting into ElasticSearch.
  local geoip_city = ngx_var.geoip_city
  if geoip_city then
    local encoding_converter = iconv.new("utf-8//IGNORE", "iso-8859-1")
    local geoip_city_encoding_err
    geoip_city, geoip_city_encoding_err  = encoding_converter:iconv(geoip_city)
    if geoip_city_encoding_err then
      ngx.log(ngx.ERR, "encoding error for geoip city: ", geoip_city_encoding_err, geoip_city)
    end
  end

  -- Put together the basic log data.
  local id = ngx_var.x_api_umbrella_request_id
  local data = {
    denied_reason = ngx_ctx.gatekeeper_denied_code,
    id = id,
    request_accept = truncate_header(request_headers["accept"], 200),
    request_accept_encoding = truncate_header(request_headers["accept-encoding"], 200),
    request_basic_auth_username = ngx_var.remote_user,
    request_connection = truncate_header(request_headers["connection"], 200),
    request_content_type = truncate_header(request_headers["content-type"], 200),
    request_ip = ngx_var.remote_addr,
    request_ip_city = geoip_city,
    request_ip_country = ngx_var.geoip_city_country_code,
    request_ip_region = ngx_var.geoip_region,
    request_method = ngx_var.request_method,
    request_origin = truncate_header(request_headers["origin"], 200),
    request_referer = truncate_header(request_headers["referer"], 200),
    request_size = tonumber(ngx_var.request_length),
    request_url_host = truncate_header(request_headers["host"], 200),
    request_url_port = ngx_var.real_port,
    request_url_scheme = ngx_var.real_scheme,
    request_user_agent = truncate_header(request_headers["user-agent"], 400),
    response_age = tonumber(response_headers["age"]),
    response_cache = truncate_header(response_headers["x-cache"], 200),
    response_content_encoding = truncate_header(response_headers["content-encoding"], 200),
    response_content_length = tonumber(response_headers["content-length"]),
    response_content_type = truncate_header(response_headers["content-type"], 200),
    response_server = ngx_var.upstream_http_server,
    response_size = tonumber(ngx_var.bytes_sent),
    response_status = tonumber(ngx_var.status),
    response_transfer_encoding = truncate_header(response_headers["transfer-encoding"], 200),
    timer_internal = ngx_ctx.internal_overhead,
    timer_response = tonumber(ngx_var.request_time),
    timestamp_utc = tonumber(ngx_var.msec),
    user_id = ngx_ctx.user_id,

    -- Deprecated
    legacy_api_key = ngx_ctx.api_key,
    legacy_user_email = ngx_ctx.user_email,
    legacy_user_registration_source = ngx_ctx.user_registration_source,
  }

  local utc_sec = data["timestamp_utc"]
  local tz_offset = timezone:find_current(utc_sec).gmtoff
  local tz_sec = utc_sec + tz_offset
  local tz_time = os.date("!%Y-%m-%d %H:%M:00", tz_sec)

  -- Determine the first day in the ISO week (the most recent Monday).
  local tz_week = luatz.gmtime(tz_sec)
  if tz_week.wday == 1 then
    tz_week.day = tz_week.day - 6
    tz_week:normalize()
  elseif tz_week.wday > 2 then
    tz_week.day = tz_week.day - tz_week.wday + 2
    tz_week:normalize()
  end

  data["timestamp_tz_offset"] = tz_offset * 1000
  data["timestamp_tz_year"] = string.sub(tz_time, 1, 4) .. "-01-01" -- YYYY-01-01
  data["timestamp_tz_month"] = string.sub(tz_time, 1, 7) .. "-01" -- YYYY-MM-01
  data["timestamp_tz_week"] = tz_week:strftime("%Y-%m-%d") -- YYYY-MM-DD of first day in ISO week.
  data["timestamp_tz_date"] = string.sub(tz_time, 1, 10) -- YYYY-MM-DD
  data["timestamp_tz_hour"] = string.sub(tz_time, 1, 13) .. ":00:00" -- YYYY-MM-DD HH:00:00
  data["timestamp_tz_minute"] = tz_time -- YYYY-MM-DD HH:MM:00

  -- Check for log data set by the separate api backend proxy
  -- (log_api_backend_proxy.lua). This is used for timing information.
  local log_timing_id = id .. "_upstream_response_time"
  local timer_backend_response = ngx.shared.logs:get(log_timing_id)
  if timer_backend_response then
    data["timer_backend_response"] = timer_backend_response

    -- Try to determine the overhead API Umbrella incurred on the request.
    -- First we compare the upstream times from this initial proxy to the
    -- backend api router proxy. Note that we don't use the "request_time"
    -- variables, since that could be affected by slow clients.
    data["timer_proxy_overhead"] = (tonumber(ngx_var.upstream_response_time) or 0) - timer_backend_response

    -- Since we're using the upstream response times for determining overhead,
    -- next add in the amount of time we've calculated that we've used
    -- internally in the Lua code.
    --
    -- Note: Due to how openresty caches the ngx.now() calls (unless we call
    -- ngx.update_time, which we don't want to do on every request), this timer
    -- will be very approximate, but we mainly want this for detecting if
    -- things really start to increase dramatically.
    if data["timer_internal"] then
      data["timer_proxy_overhead"] = data["timer_proxy_overhead"] + data["timer_internal"]
    end
  end

  if not data["timer_proxy_overhead"] then
    data["timer_proxy_overhead"] = ngx_ctx.internal_overhead
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

  if request_headers["user-agent"] then
    local user_agent_data = user_agent_parser(request_headers["user-agent"])
    if user_agent_data then
      data["request_user_agent_family"] = user_agent_data["family"]
      data["request_user_agent_type"] = user_agent_data["type"]
    end
  end

  -- The geoip database returns "00" for unknown regions sometimes:
  -- http://maxmind.com/download/geoip/kml/index.html Remove these and treat
  -- these as nil.
  if data["request_ip_region"] == "00" then
    data["request_ip_region"] = nil
  end

  local geoip_latitude = ngx_var.geoip_latitude
  if geoip_latitude then
    data["request_ip_lat"] = tonumber(geoip_latitude)
    data["request_ip_lon"] = tonumber(ngx_var.geoip_longitude)

    data["legacy_request_ip_location"] = {
      lat = data["request_ip_lat"],
      lon = data["request_ip_lon"],
    }
  end

  local syslog_message = "<" .. syslog_priority .. ">"
    .. syslog_version
    .. " " .. os.date("!%Y-%m-%dT%TZ", data["timestamp_utc"] / 1000) -- timestamp
    .. " -" -- hostname
    .. " api-umbrella" -- app-name
    .. " -" -- procid
    .. " -" -- msgid
    .. " -" -- structured-data
    .. " @cee:" -- CEE-enhanced logging for rsyslog to parse JSON
    .. elasticsearch_encode_json(data) -- JSON data
    .. "\n"

  -- Check the syslog message length to ensure it doesn't exceed the configured
  -- rsyslog maxMessageSize value.
  --
  -- In general, this shouldn't be possible, since URLs can't exceed 8KB, and
  -- we truncate the various headers that users can control for logging
  -- purposes. However, this provides an extra sanity check to ensure this
  -- doesn't unexpectedly pop up (eg, if we add additional headers we forget to
  -- truncate).
  local syslog_message_length = string.len(syslog_message)
  if syslog_message_length > 32000 then
    ngx.log(ngx.ERR, "request syslog message longer than expected - analytics logging may fail: ", syslog_message_length)
  end

  local _, err = logger.log(syslog_message)
  if err then
    ngx.log(ngx.ERR, "failed to log message: ", err)
    return
  end

  if timer_backend_response then
    ngx.shared.logs:delete(log_timing_id)
  end

  if data["request_ip_lat"] then
    cache_new_city_geocode(data)
  end
end

local ok, err = pcall(log_request)
if not ok then
  ngx.log(ngx.ERR, "failed to log request: ", err)
end
