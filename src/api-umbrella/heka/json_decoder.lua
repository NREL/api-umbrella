-- luacheck: globals read_message inject_message process_message

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
  msg["Payload"] = read_message("Payload")

  local ok = pcall(inject_message, msg)
  if not ok then
    return -1, "inject_message failed"
  end

  return 0
end
