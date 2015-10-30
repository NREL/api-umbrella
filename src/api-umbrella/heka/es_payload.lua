-- luacheck: globals read_config read_message add_to_payload inject_payload process_message

require "string"
local cjson = require "cjson"
local elasticsearch = require "elasticsearch"

local index = read_config("index") or "heka-%{%Y.%m.%d}"
local type_name = read_config("type_name") or "message"

function process_message()
  local ok, json = pcall(cjson.decode, read_message("Payload"))
  if not ok then
    return -1, "JSON decode failed"
  end

  local timestamp = json["request_at"] * 1e6
  local id = json["id"]
  json["id"] = nil
  json["source"] = nil

  local idx_json = elasticsearch.bulkapi_index_json(index, type_name, id, timestamp)
  local payload = cjson.encode(json)

  add_to_payload(idx_json, "\n", payload)
  -- ES bulk api expects newline at the end of the payload.
  if not string.match(payload, "\n$") then
    add_to_payload("\n")
  end

  inject_payload()
  return 0
end
