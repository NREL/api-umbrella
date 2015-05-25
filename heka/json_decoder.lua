require "cjson"

local msg = {
  Timestamp  = nil,
  EnvVersion = nil,
  Host       = nil,
  Type       = nil,
  Payload    = nil,
  Fields     = nil,
  Severity   = nil
}

function process_message()
  local ok, json = pcall(cjson.decode, read_message("Payload"))
  if not ok then
    return -1, "JSON decode failed"
  end

  -- msg["Timestamp"] = json["request_at_msec"] * 1e6
  --msg["EnvVersion"] = json["id"]
  --msg["Fields"] = json
  msg["Payload"] = read_message("Payload")

  --json["id"] = nil
  --json["request_at_msec"] = nil

  local ok = pcall(inject_message, msg)
  if not ok then
    return -1, "inject_message failed"
  end

  return 0
end
