local json_encode = require "api-umbrella.utils.json_encode"
local request_api_umbrella_roles = require "api-umbrella.utils.request_api_umbrella_roles"

local required_role = "api-umbrella-system-info"
local current_roles = request_api_umbrella_roles(ngx.ctx)
if not current_roles[required_role] then
  ngx.status = 403
  ngx.header["Content-Type"] = "application/json"
  ngx.say(json_encode({
    errors = {
      {
        code = "API_KEY_UNAUTHORIZED",
        message = "The api_key supplied is not authorized to access the given service.",
      },
    },
  }))
  return ngx.exit(ngx.HTTP_OK)
end

local dicts = {
  "active_config",
  "active_config_ipc",
  "active_config_locks",
  "api_users",
  "api_users_ipc",
  "api_users_locks",
  "api_users_misses",
  "geocode_city_cache",
  "interval_locks",
  "jobs",
  "locks",
  "rate_limit_counters",
  "rate_limit_exceeded",
}

local function format_bytes(bytes)
  if bytes > 1024 * 1024 * 1024 then
    return tonumber(string.format("%.2f", bytes / 1024 / 1024 / 1024)) .. "g"
  elseif bytes > 1024 * 1024 then
    return tonumber(string.format("%.2f", bytes / 1024 / 1024)) .. "m"
  elseif bytes > 1024 then
    return tonumber(string.format("%.2f", bytes / 1024)) .. "k"
  else
    return tostring(tonumber(string.format("%.2f", bytes)))
  end
end

local response = {}

for _, dict in ipairs(dicts) do
  local data = {
    capacity_bytes = ngx.shared[dict]:capacity(),
    free_space_bytes = ngx.shared[dict]:free_space(),
  }

  data["capacity"] = format_bytes(data["capacity_bytes"])
  data["free_space"] = format_bytes(data["free_space_bytes"])
  data["usage"] = tonumber(string.format("%.2f", 1 - data["free_space_bytes"] / data["capacity_bytes"]))
  data["usage_percent"] = data["usage"] * 100 .. "%"

  response[dict] = data
end

ngx.header["Content-Type"] = "application/json"
ngx.say(json_encode(response))
