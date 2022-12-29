local config = require("api-umbrella.utils.load_config")()

local elasticsearch_encode_json = require "api-umbrella.utils.elasticsearch_encode_json"
local get_user = require("api-umbrella.proxy.stores.api_users_store").get
local http = require "resty.http"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local log_utils = require "api-umbrella.proxy.log_utils"
local luatz = require "luatz"
local user_agent_parser = require "api-umbrella.proxy.user_agent_parser"
local utils = require "api-umbrella.proxy.utils"

local truncate_header = log_utils.truncate_header

local bulk_size = 1000
local log_format = [=[
  \A
  (?<remote_addr>[^ ]+)
  [ ]
  -
  [ ]
  (?<remote_user>[^ ]+)
  [ ]
  \[
    (?<time_local_day>[^/]+)
    /
    (?<time_local_month>[^/]+)
    /
    (?<time_local_year>[^:]+)
    :
    (?<time_local_hour>[^/]+)
    :
    (?<time_local_min>[^/]+)
    :
    (?<time_local_sec>[^/]+)
    [ ]
    (?<time_local_tz_hour>[\-+][0-9][0-9])
    (?<time_local_tz_min>[0-9][0-9])
  \]
  [ ]
  "
    (?<request_method>[^ ]+)
    [ ]
    (?<request_uri>.+?)
    (
      [ ]
      (?<request_http_version>HTTP/[^"]+)
    )?
  "
  [ ]
  (?<status>[^ ]+)
  [ ]
  (?<body_bytes_sent>[^ ]+)
  [ ]
  "(?<http_referer>[^"]*)"
  [ ]
  "(?<http_user_agent>[^"]*)"
  [ ]
  (?<x_api_umbrella_request_id>[^ ]*)
  [ ]
  (?<scheme>[^:]+)://(?<host>[^:]+):(?<server_port>[^ ]+)
  [ ]
  (?<request_time>[^ ]+)
  [ ]
  (?<sent_http_x_cache>[^ ]+)
]=]

local timezone = luatz.get_tz(config["analytics"]["timezone"])

local function parse_time(matches)
  local month = matches["time_local_month"]
  if month == "Jan" then
    month = "01"
  elseif month == "Feb" then
    month = "02"
  elseif month == "Mar" then
    month = "03"
  elseif month == "Apr" then
    month = "04"
  elseif month == "May" then
    month = "05"
  elseif month == "Jun" then
    month = "06"
  elseif month == "Jul" then
    month = "07"
  elseif month == "Aug" then
    month = "08"
  elseif month == "Sep" then
    month = "09"
  elseif month == "Oct" then
    month = "10"
  elseif month == "Nov" then
    month = "11"
  elseif month == "Dec" then
    month = "12"
  end

  local str = matches["time_local_year"] .. "-" ..
    month .. "-" ..
    matches["time_local_day"] .. "T" ..
    matches["time_local_hour"] .. ":" ..
    matches["time_local_min"] .. ":" ..
    matches["time_local_sec"] ..
    matches["time_local_tz_hour"] .. ":" ..
    matches["time_local_tz_min"]

  local tt, tt_offset = luatz.parse.rfc_3339(str)
  return tt:timestamp() - tt_offset
end

local bulk_commands = {}
local last_bulk_commands_timestamp = nil
local function flush_bulk_commands()
  if #bulk_commands == 0 then
    return
  end

  print("\n" .. os.date("!%Y-%m-%dT%TZ") .. " - Log data from " .. os.date("!%Y-%m-%dT%TZ", last_bulk_commands_timestamp / 1000))

  local httpc = http.new()
  httpc:set_timeout(120000)
  httpc:connect({
    scheme = "http",
    host = config["elasticsearch"]["_first_server"]["host"],
    port = config["elasticsearch"]["_first_server"]["port"],
  })

  local res, err = httpc:request({
    method = "POST",
    path = "/_bulk",
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = table.concat(bulk_commands, "\n") .. "\n",
  })
  if err then
    ngx.log(ngx.ERR, "mongodb query failed: " .. err)
    return false
  end

  local body, body_err = res:read_body()
  if not body then
    ngx.log(ngx.ERR, body_err)
    return false
  end

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    ngx.log(ngx.ERR, keepalive_err)
  end

  local response = json_decode(body)
  if type(response["items"]) ~= "table" then
    ngx.log(ngx.ERR, "unexpected error: " .. (body or nil))
    return false
  end

  local skipped_count = 0
  local created_count = 0
  local error_count = 0
  local created_ids = {}
  for _, item in ipairs(response["items"]) do
    if item["create"]["status"] == 409 then
      io.write(string.char(27) .. "[30m" .. string.char(27) .. "[2m-" .. string.char(27) .. "[0m")
      skipped_count = skipped_count + 1
    elseif item["create"]["status"] == 201 then
      io.write(string.char(27) .. "[32m" .. string.char(27) .. "[1m✔" .. string.char(27) .. "[0m")
      created_count = created_count + 1
      table.insert(created_ids, item["create"]["_id"])
    else
      io.write(string.char(27) .. "[31m" .. string.char(27) .. "[1m✖" .. string.char(27) .. "[0m")
      error_count = error_count + 1
    end
  end
  print("")
  if created_count > 0 then
    print("Created: " .. created_count)
    print("Created IDs: " .. table.concat(created_ids, ", "))
  end
  if skipped_count > 0 then
    print("Skipped (already exists): " .. skipped_count)
  end
  if error_count > 0 then
    print("Errors: " .. error_count)
  end

  bulk_commands = {}
  last_bulk_commands_timestamp = nil
end

local function log_request(line_matches)
  local timestamp = parse_time(line_matches)
  local data = {
    id = line_matches["x_api_umbrella_request_id"],
    request_basic_auth_username = line_matches["remote_user"],
    request_ip = line_matches["remote_addr"],
    request_method = line_matches["request_method"],
    request_referer = truncate_header(line_matches["http_referer"], 200),
    request_url_host = truncate_header(line_matches["host"], 200),
    request_url_port = line_matches["port"],
    request_url_scheme = line_matches["scheme"],
    request_user_agent = truncate_header(line_matches["http_user_agent"], 400),
    response_cache = truncate_header(line_matches["sent_http_x_cache"], 200),
    response_size = tonumber(line_matches["body_bytes_sent"]),
    response_status = tonumber(line_matches["status"]),
    timer_response = tonumber(line_matches["request_time"]),
    timestamp_utc = timestamp,
  }

  local api_key_url_match, err = ngx.re.match(line_matches["request_uri"], "api_key=([a-zA-Z0-9]{40})", "ijo")
  if err then
    ngx.log(ngx.ERR, "Failed to parse request_uri: ", err, line_matches["request_uri"])
  elseif api_key_url_match and api_key_url_match[1] then
    data["legacy_api_key"] = api_key_url_match[1]
  elseif data["request_basic_auth_username"] and string.len(data["request_basic_auth_username"]) == 40 then
    data["legacy_api_key"] = data["request_basic_auth_username"]
  end

  if data["legacy_api_key"] then
    local user = get_user(data["legacy_api_key"])
    if user then
      data["legacy_user_email"] = user["email"]
      data["legacy_user_registration_source"] = user["registration_source"]
    end
  end

  if data["response_status"] == 429 then
    data["denied_reason"] = "over_rate_limit"
  end

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

  if line_matches["http_user_agent"] then
    local user_agent_data = user_agent_parser(line_matches["http_user_agent"])
    if user_agent_data then
      data["request_user_agent_family"] = user_agent_data["family"]
      data["request_user_agent_type"] = user_agent_data["type"]
    end
  end

  local es_data = {
    api_key = data["legacy_api_key"],
    backend_response_time = data["timer_backend_response"],
    gatekeeper_denied_code = data["denied_reason"],
    internal_gatekeeper_time = data["timer_internal"],
    proxy_overhead = data["timer_proxy_overhead"],
    request_accept = data["request_accept"],
    request_accept_encoding = data["request_accept_encoding"],
    request_at = data["timestamp_utc"],
    request_basic_auth_username = data["request_basic_auth_username"],
    request_connection = data["request_connection"],
    request_content_type = data["request_content_type"],
    request_hierarchy = data["request_url_hierarchy"],
    request_host = data["request_url_host"],
    request_ip = data["request_ip"],
    request_ip_city = data["request_ip_city"],
    request_ip_country = data["request_ip_country"],
    request_ip_location = data["legacy_request_ip_location"],
    request_ip_region = data["request_ip_region"],
    request_method = data["request_method"],
    request_origin = data["request_origin"],
    request_path = data["request_url_path"],
    request_query = data["legacy_request_url_query_hash"],
    request_referer = data["request_referer"],
    request_scheme = data["request_url_scheme"],
    request_size = data["request_size"],
    request_url = data["legacy_request_url"],
    request_user_agent = data["request_user_agent"],
    request_user_agent_family = data["request_user_agent_family"],
    request_user_agent_type = data["request_user_agent_type"],
    response_age = data["response_age"],
    response_cache = data["response_cache"],
    response_content_encoding = data["response_content_encoding"],
    response_content_length = data["response_content_length"],
    response_content_type = data["response_content_type"],
    response_server = data["response_server"],
    response_size = data["response_size"],
    response_status = data["response_status"],
    response_time = data["timer_response"],
    response_transfer_encoding = data["response_transfer_encoding"],
    user_email = data["legacy_user_email"],
    user_id = data["user_id"],
    user_registration_source = data["legacy_user_registration_source"],
  }
  -- print(inspect(es_data))

  local index_name = "api-umbrella-logs-v1-" .. os.date("!%Y-%m", data["timestamp_utc"] / 1000)
  table.insert(bulk_commands, json_encode({
    create = {
      _index = index_name,
      _type = "log",
      _id = data["id"],
    }
  }))
  table.insert(bulk_commands, elasticsearch_encode_json(es_data))

  if not last_bulk_commands_timestamp then
    last_bulk_commands_timestamp = data["timestamp_utc"]
  end

  if #bulk_commands >= bulk_size * 2 then
    flush_bulk_commands()
  end
end

for line in io.stdin:lines() do
  if line and line ~= "" then
    local line_matches, err = ngx.re.match(line, log_format, "jox")
    -- print(inspect(line))
    -- print(inspect(line_matches))
    if err or not line_matches then
      ngx.log(ngx.ERR, "Failed to parse line: ", err, line)
    end

    for key, value in pairs(line_matches) do
      if value == "-" or value == false or value == "" then
        line_matches[key] = nil
      end
    end
    -- print(inspect(line_matches))

    ngx.ctx.original_uri_path = line_matches["request_uri"]
    ngx.ctx.original_request_uri = line_matches["request_uri"]
    if not log_utils.ignore_request() then
      if line_matches["x_api_umbrella_request_id"] then
        local port = tonumber(line_matches["server_port"])
        if port ~= config["router"]["api_backends"]["port"] and port ~= config["web"]["port"] then
          log_request(line_matches)
        end
      end
    end
  end
end

flush_bulk_commands()
