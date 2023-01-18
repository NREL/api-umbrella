local config = require("api-umbrella.utils.load_config")()
local escape_uri_non_ascii = require "api-umbrella.utils.escape_uri_non_ascii"
local icu_date = require "icu-date-ffi"
local json_encode = require "api-umbrella.utils.json_encode"
local logger = require "resty.logger.socket"
local pg_utils = require "api-umbrella.utils.pg_utils"
local plutils = require "pl.utils"
local round = require "api-umbrella.utils.round"
local user_agent_parser = require "api-umbrella.proxy.user_agent_parser"

local split = plutils.split

local syslog_facility = 16 -- local0
local syslog_severity = 6 -- info
local syslog_priority = (syslog_facility * 8) + syslog_severity
local syslog_version = 1

local ZONE_OFFSET = icu_date.fields.ZONE_OFFSET
local DST_OFFSET = icu_date.fields.DST_OFFSET
local DAY_OF_WEEK = icu_date.fields.DAY_OF_WEEK
-- Setup the date object in the analytics timezone, and set the first day of
-- the week to Mondays for ISO week calculations.
local date = icu_date.new({ zone_id = config["analytics"]["timezone"] })
date:set_attribute(icu_date.attributes.FIRST_DAY_OF_WEEK, 2)

local _M = {}

local function truncate_string(value, max_length)
  if string.len(value) > max_length then
    return string.sub(value, 1, max_length)
  else
    return value
  end
end

local function truncate(value, max_length)
  if not value or type(value) ~= "string" then
    return nil
  end

  return truncate_string(value, max_length)
end

local function lowercase_truncate(value, max_length)
  if not value or type(value) ~= "string" then
    return nil
  end

  return string.lower(truncate_string(value, max_length))
end

local function uppercase_truncate(value, max_length)
  if not value or type(value) ~= "string" then
    return nil
  end

  return string.upper(truncate_string(value, max_length))
end

-- To make drill-downs queries easier, split up how the path is stored.
--
-- We store this in slightly different, but similar fashions for SQL storage
-- versus ElasticSearch storage.
--
-- A request like this:
--
-- http://example.com/api/foo/bar.json?param=example
--
-- Will get stored like this for SQL storage:
--
-- request_url_hierarchy_level1 = /api/
-- request_url_hierarchy_level2 = /api/foo/
-- request_url_hierarchy_level3 = /api/foo/bar.json
--
-- And gets indexed as this array for ElasticSearch storage:
--
-- 0/example.com/
-- 1/example.com/api/
-- 2/example.com/api/foo/
-- 3/example.com/api/foo/bar.json
--
-- This is similar to ElasticSearch's built-in path_hierarchy tokenizer, but
-- prefixes each token with a depth counter, so we can more easily and
-- efficiently facet on specific levels (for example, a regex query of "^0/"
-- would return all the totals for each domain).
--
-- See:
-- http://wiki.apache.org/solr/HierarchicalFaceting
-- http://www.springyweb.com/2012/01/hierarchical-faceting-with-elastic.html
function _M.set_url_hierarchy(data)
  -- Remote duplicate slashes (eg foo//bar becomes foo/bar).
  local cleaned_path = ngx.re.gsub(data["request_url_path"], "//+", "/", "jo")

  -- Remove trailing slashes. This is so that we can always distinguish the
  -- intermediate paths versus the actual endpoint.
  cleaned_path = ngx.re.gsub(cleaned_path, "/$", "", "jo")

  -- Remove the slash prefix so that split doesn't return an empty string as
  -- the first element.
  cleaned_path = ngx.re.gsub(cleaned_path, "^/", "", "jo")

  -- Split the path by slashes limiting to 6 levels deep (everything beyond
  -- the 6th level will be included on the 6th level string). This is to
  -- prevent us from having to have unlimited depths for flattened SQL storage.
  local path_parts = split(cleaned_path, "/", true, 6)

  -- Setup top-level host hierarchy for ElasticSearch storage.
  data["request_url_hierarchy"] = {}
  local host_level = data["request_url_host"]
  if #path_parts > 0 then
    host_level = host_level .. "/"
  end
  data["request_url_hierarchy_level0"] = host_level
  table.insert(data["request_url_hierarchy"], "0/" .. host_level)

  local path_tree = "/"
  for index, _ in ipairs(path_parts) do
    local path_level = path_parts[index]

    -- Add a trailing slash to all parent paths, but not the last path. This
    -- is done for two reasons:
    --
    -- 1. So we can distinguish between paths with common prefixes (for example
    --    /api/books vs /api/book)
    -- 2. So we can distinguish intermediate parents from the "leaf" path (for
    --    example, we know how to distinguish "/api/foo" when there are two
    --    requests to "/api/foo" and "/api/foo/bar"--in the first, /api/foo is
    --    the actual API call, whereas in the second, /api/foo is just an
    --    intermediate path).
    if index < #path_parts then
      path_level = path_level .. "/"
    end

    -- Store in the request_url_path_level(1-6) fields for SQL storage.
    data["request_url_hierarchy_level" .. index] = path_level

    -- Store as an array for ElasticSearch storage.
    path_tree = path_tree .. path_level
    local path_token = index .. "/" .. data["request_url_host"] .. path_tree
    table.insert(data["request_url_hierarchy"], path_token)
  end
end

-- Cache the last geocoded location for each city in a separate index. When
-- faceting by city names on the log index (for displaying on a map), there
-- doesn't appear to be an easy way to fetch the associated locations for each
-- city facet. This allows us to perform a separate lookup to fetch the
-- pre-geocoded locations for each city.
--
-- The geoip stuff actually returns different geocodes for different parts of
-- cities. This approach rolls up each city to the last geocoded location
-- within that city, so it's not perfect, but for now it'll do.
local function cache_city_geocode(premature, data)
  if premature then
    return
  end

  if not data["request_ip_country"] or not data["request_ip_lon"] or not data["request_ip_lat"] then
    ngx.log(ngx.WARN, "Skipping city location caching for empty location")
    return
  end

  local _, err = pg_utils.query("INSERT INTO analytics_cities(country, region, city, location) VALUES(:country, :region, :city, point(:lon, :lat)) ON CONFLICT (country, region, city) DO UPDATE SET location = EXCLUDED.location", {
    country = data["request_ip_country"],
    region = data["request_ip_region"],
    city = data["request_ip_city"],
    lon = data["request_ip_lon"],
    lat = data["request_ip_lat"],
  })
  if err then
    ngx.log(ngx.ERR, "failed to cache city location: ", err)
  end
end

function _M.ignore_request(ngx_ctx)
  -- Only log API requests (not website backend requests).
  if ngx_ctx.matched_api then
    local settings = ngx_ctx.settings

    -- Don't log some of our internal API calls.
    if settings and settings["disable_analytics"] then
      return true
    else
      return false
    end
  else
    return true
  end
end

function _M.sec_to_ms(value)
  value = tonumber(value)
  if not value then
    return nil
  end

  -- Round the results after turning into milliseconds. Since all the nginx
  -- timers only have millisecond precision, any decimals left after
  -- converting are just an artifact of the original float storage or math
  -- (eg, 1.00001... or 1.999988..).
  return round(value * 1000)
end

function _M.cache_new_city_geocode(data)
  local id = (data["request_ip_country"] or "") .. "-" .. (data["request_ip_region"] or "") .. "-" .. (data["request_ip_city"] or "")

  -- Only cache the first city location per startup to prevent lots of indexing
  -- churn re-indexing the same city.
  if not ngx.shared.geocode_city_cache:get(id) then
    local set_ok, set_err, set_forcible = ngx.shared.geocode_city_cache:set(id, true)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set city in 'geocode_city_cache' shared dict: ", set_err)
    elseif set_forcible then
      ngx.log(ngx.WARN, "forcibly set city in 'geocode_city_cache' shared dict (shared dict may be too small)")
    end

    -- Perform the actual cache call in a timer because the http library isn't
    -- supported directly in the log_by_lua context.
    ngx.timer.at(0, cache_city_geocode, data)
  end
end

function _M.set_request_ip_geo_fields(data, ngx_var)
  data["request_ip_country"] = ngx_var.geoip2_data_country_code
  data["request_ip_region"] = ngx_var.geoip2_data_subdivision_code
  data["request_ip_city"] = ngx_var.geoip2_data_city_name

  -- Compatibility with the GeoIP v1 way to store country-less results, by
  -- mapping certain situations into custom country codes:
  -- https://dev.maxmind.com/geoip/geoip2/whats-new-in-geoip2/#Custom_Country_Codes
  -- https://dev.maxmind.com/geoip/legacy/codes/iso3166/
  if not data["request_ip_country"] then
    local continent_code = ngx_var.geoip2_data_continent_code
    if continent_code == "AS" then
      data["request_ip_country"] = "AP"
    elseif continent_code == "EU" then
      data["request_ip_country"] = "EU"
    elseif ngx_var.geoip2_data_is_anonymous_proxy == "1" then
      data["request_ip_country"] = "A1"
    elseif ngx_var.geoip2_data_is_satellite_provider == "1" then
      data["request_ip_country"] = "A2"
    end
  end

  local geoip_latitude = ngx_var.geoip2_data_latitude
  if geoip_latitude then
    data["request_ip_lat"] = tonumber(geoip_latitude)
    data["request_ip_lon"] = tonumber(ngx_var.geoip2_data_longitude)
  end
end

function _M.set_computed_timestamp_fields(data)
  -- Generate a string of current timestamp in the analytics timezone.
  --
  -- Note that we use os.date instead of icu-date's "format" function, since in
  -- some microbenchmarks, this approach is faster.
  date:set_millis(data["timestamp_utc"])
  local tz_offset = date:get(ZONE_OFFSET) + date:get(DST_OFFSET)
  local tz_time = os.date("!%Y-%m-%d %H:%M:00", (date:get_millis() + tz_offset) / 1000)

  -- Determine the first day in the ISO week (the most recent Monday).
  date:set(DAY_OF_WEEK, 2)
  local week_tz_offset = date:get(ZONE_OFFSET) + date:get(DST_OFFSET)
  local tz_week = os.date("!%Y-%m-%d", (date:get_millis() + week_tz_offset) / 1000)

  data["timestamp_tz_offset"] = tz_offset
  data["timestamp_tz_year"] = string.sub(tz_time, 1, 4) .. "-01-01" -- YYYY-01-01
  data["timestamp_tz_month"] = string.sub(tz_time, 1, 7) .. "-01" -- YYYY-MM-01
  data["timestamp_tz_week"] = tz_week -- YYYY-MM-DD of first day in ISO week.
  data["timestamp_tz_date"] = string.sub(tz_time, 1, 10) -- YYYY-MM-DD
  data["timestamp_tz_hour"] = string.sub(tz_time, 1, 13) .. ":00:00" -- YYYY-MM-DD HH:00:00
  data["timestamp_tz_minute"] = tz_time -- YYYY-MM-DD HH:MM:00
end

function _M.set_computed_url_fields(data, ngx_ctx)
  data["request_url_host"] = lowercase_truncate(data["request_url_host"], 200)

  -- Extract just the path portion of the URL.
  --
  -- Note: we're extracting this from the original "request_uri" variable here,
  -- rather than just using the original "uri" variable by itself, since
  -- "request_uri" has the raw encoding of the URL as it was passed in (eg, for
  -- url escaped encodings), which we'll prefer for consistency.
  local parts = split(ngx_ctx.original_request_uri, "?", true, 2)
  data["request_url_path"] = escape_uri_non_ascii(parts[1])

  -- Extract the query string arguments.
  --
  -- Note: We're using the original args (rather than the current args, where
  -- we may have already removed this field), since we want the logged URL to
  -- reflect the original URL (and not after any internal rewriting).
  if parts[2] then
    data["request_url_query"] = escape_uri_non_ascii(parts[2])
  end

  data["legacy_request_url"] = data["request_url_scheme"] .. "://" .. data["request_url_host"] .. data["request_url_path"]
  if data["request_url_query"] then
    data["legacy_request_url"] = data["legacy_request_url"] .. "?" .. data["request_url_query"]
  end

  _M.set_url_hierarchy(data)
end

function _M.set_computed_user_agent_fields(data)
  if data["request_user_agent"] then
    local user_agent_data = user_agent_parser(data["request_user_agent"])
    if user_agent_data then
      data["request_user_agent_family"] = user_agent_data["family"]
      data["request_user_agent_type"] = user_agent_data["type"]
    end
  end
end

function _M.normalized_data(data)
  local normalized = {
    api_backend_id = lowercase_truncate(data["api_backend_id"], 36),
    api_backend_url_match_id = lowercase_truncate(data["api_backend_url_match_id"], 36),
    denied_reason = lowercase_truncate(data["denied_reason"], 50),
    id = lowercase_truncate(data["id"], 20),
    request_accept = truncate(data["request_accept"], 200),
    request_accept_encoding = truncate(data["request_accept_encoding"], 200),
    request_basic_auth_username = truncate(data["request_basic_auth_username"], 200),
    request_connection = truncate(data["request_connection"], 200),
    request_content_type = truncate(data["request_content_type"], 200),
    request_ip = lowercase_truncate(data["request_ip"], 45),
    request_ip_city = truncate(data["request_ip_city"], 200),
    request_ip_country = uppercase_truncate(data["request_ip_country"], 2),
    request_ip_lat = tonumber(data["request_ip_lat"]),
    request_ip_lon = tonumber(data["request_ip_lon"]),
    request_ip_region = uppercase_truncate(data["request_ip_region"], 2),
    request_method = uppercase_truncate(data["request_method"], 10),
    request_origin = truncate(data["request_origin"], 200),
    request_referer = truncate(data["request_referer"], 200),
    request_size = tonumber(data["request_size"]),
    request_url_hierarchy = data["request_url_hierarchy"],
    request_url_host = lowercase_truncate(data["request_url_host"], 200),
    request_url_path = truncate(data["request_url_path"], 4000),
    request_url_hierarchy_level0 = truncate(data["request_url_hierarchy_level0"], 200),
    request_url_hierarchy_level1 = truncate(data["request_url_hierarchy_level1"], 200),
    request_url_hierarchy_level2 = truncate(data["request_url_hierarchy_level2"], 200),
    request_url_hierarchy_level3 = truncate(data["request_url_hierarchy_level3"], 200),
    request_url_hierarchy_level4 = truncate(data["request_url_hierarchy_level4"], 200),
    request_url_hierarchy_level5 = truncate(data["request_url_hierarchy_level5"], 200),
    request_url_hierarchy_level6 = truncate(data["request_url_hierarchy_level6"], 200),
    request_url_port = tonumber(data["request_url_port"]),
    request_url_query = truncate(data["request_url_query"], 4000),
    request_url_scheme = lowercase_truncate(data["request_url_scheme"], 10),
    request_user_agent = truncate(data["request_user_agent"], 400),
    request_user_agent_family = truncate(data["request_user_agent_family"], 100),
    request_user_agent_type = truncate(data["request_user_agent_type"], 100),
    response_age = tonumber(data["response_age"]),
    response_cache = truncate(data["response_cache"], 200),
    response_content_encoding = truncate(data["response_content_encoding"], 200),
    response_content_length = tonumber(data["response_content_length"]),
    response_content_type = truncate(data["response_content_type"], 200),
    response_server = truncate(data["response_server"], 100),
    response_size = tonumber(data["response_size"]),
    response_status = tonumber(data["response_status"]),
    response_transfer_encoding = truncate(data["response_transfer_encoding"], 200),
    timer_response = tonumber(data["timer_response"]),
    timestamp_tz_date = uppercase_truncate(data["timestamp_tz_date"], 20),
    timestamp_tz_hour = uppercase_truncate(data["timestamp_tz_hour"], 20),
    timestamp_tz_minute = uppercase_truncate(data["timestamp_tz_minute"], 20),
    timestamp_tz_month = uppercase_truncate(data["timestamp_tz_month"], 20),
    timestamp_tz_offset = tonumber(data["timestamp_tz_offset"]),
    timestamp_tz_week = uppercase_truncate(data["timestamp_tz_week"], 20),
    timestamp_tz_year = uppercase_truncate(data["timestamp_tz_year"], 20),
    timestamp_utc = tonumber(data["timestamp_utc"]),
    user_id = lowercase_truncate(data["user_id"], 36),

    -- Deprecated
    legacy_api_key = truncate(data["legacy_api_key"], 40),
    legacy_request_url = truncate(data["legacy_request_url"], 8000),
    legacy_user_email = truncate(data["legacy_user_email"], 200),
    legacy_user_registration_source = truncate(data["legacy_user_registration_source"], 200),
  }

  if normalized["request_url_hierarchy"] then
    for index, path in ipairs(normalized["request_url_hierarchy"]) do
      normalized["request_url_hierarchy"][index] = truncate(path, 400)
    end
  end

  return normalized
end

function _M.build_syslog_message(data)
  local syslog_message = "<" .. syslog_priority .. ">"
    .. syslog_version
    .. " " .. os.date("!%Y-%m-%dT%TZ", data["timestamp_utc"] / 1000) -- timestamp
    .. " -" -- hostname
    .. " api-umbrella" -- app-name
    .. " -" -- procid
    .. " -" -- msgid
    .. " -" -- structured-data
    .. " @cee:" -- CEE-enhanced logging for rsyslog to parse JSON
    .. json_encode({ raw = data }) -- JSON data
    .. "\n"

  return syslog_message
end

function _M.send_syslog_message(syslog_message)
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

  return logger.log(syslog_message)
end

return _M
