local icu_date = require "icu-date"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local date = icu_date.new()
local format_iso8601 = icu_date.formats.pattern("YYYY-MM-dd'T'HH:mm:ssZZZZZ")
local format_postgres = icu_date.formats.pattern("YYYY-MM-dd HH:mm:ss.SSSSxxx")
local format_postgres_no_millis = icu_date.formats.pattern("YYYY-MM-dd HH:mm:ssxxx")

local _M = {}

local function parse_postgres(string)
  local ok, err
  ok = pcall(date.parse, date, format_postgres, string)
  if not ok then
    ok, err = xpcall(date.parse, xpcall_error_handler, date, format_postgres_no_millis, string)
    if not ok then
      ngx.log(ngx.ERR, "Failed to parse postgres time (" .. (tostring(string) or "") .. "): " .. (tostring(err) or ""))
      return false
    end
  end

  -- Since the postgres format may include a custom time zone, be sure to
  -- normalize all parsed times to UTC.
  date:set_time_zone_id("UTC")
end

function _M.timestamp_to_iso8601(timestamp)
  if not timestamp then
    return nil
  end

  date:set_millis(timestamp * 1000)
  return date:format(format_iso8601)
end

function _M.postgres_to_timestamp(string)
  if not string then
    return nil
  end

  parse_postgres(string)
  return date:get_millis() / 1000
end

function _M.postgres_to_iso8601(string)
  if not string then
    return nil
  end

  parse_postgres(string)
  return date:format(format_iso8601)
end

return _M
