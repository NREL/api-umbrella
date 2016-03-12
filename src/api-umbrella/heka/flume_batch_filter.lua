-- luacheck: globals read_message add_to_payload inject_payload process_message

require "os"
require "string"
require "table"
require "cjson"

local flush_count = tonumber(read_config("flush_count")) or 0
local count_since_flush = 0

local any = false

local function flush()
  if any then
    add_to_payload("]")
    inject_payload("json", "flume_batch")
    any = false
  end
  count_since_flush = 0
end

function process_message()
  local ok, json = pcall(cjson.decode, read_message("Payload"))
  if not ok then
    return -1, "JSON decode failed" .. (read_message("Payload") or "NOTHING")
  end

  json["request_url_hierarchy"] = nil
  json["_heka_timestamp"] = nil
  json["timestamp"] = json["request_at"]
  json["request_at_year"] = tonumber(os.date("%Y", json["request_at"] / 1000))
  json["request_at_month"] = tonumber(os.date("%m", json["request_at"] / 1000))
  json["request_at_date"] = os.date("%Y-%m-%d", json["request_at"] / 1000)
  json["request_at_hour"] = tonumber(os.date("%H", json["request_at"] / 1000))

  local separator = ","
  if not any then
    separator = "["
  end
  add_to_payload(separator, cjson.encode({
    headers = json,
    body = "",
  }))
  any = true

  if flush_count > 0 then
    count_since_flush = count_since_flush + 1
    if count_since_flush >= flush_count then
      flush()
    end
  end

  return 0
end

function timer_event(ns)
  flush()
end
