local active_config_store = require("api-umbrella.proxy.stores.active_config_store")
local config = require("api-umbrella.utils.load_config")()
local http = require "resty.http"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local compress_json_encode = require("api-umbrella.utils.compressed_json").compress_json_encode
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local cache = active_config_store.cache
local get_active_config = active_config_store.get
local jobs_dict = ngx.shared.jobs
local refresh_local_active_config_cache = active_config_store.refresh_local_cache

-- Refresh cache per request if background polling is disabled.
local state_ttl = 1
if config["router"]["active_config"]["refresh_local_cache_interval"] == 0 then
  refresh_local_active_config_cache()

  -- If background polling is disabled, then this probably indicates the test
  -- environment, so also also don't cache the state for very long.
  state_ttl = 0.001
end

local active_config = get_active_config()

local function fetch_web_app_state()
  local httpc = http.new()
  httpc:set_timeout(2000)

  local connect_ok, connect_err = httpc:connect({
    scheme = "http",
    host = config["web"]["host"],
    port = config["web"]["port"],
  })

  if not connect_ok then
    httpc:close()
    return nil, "failed to connect: ".. (connect_err or "")
  end

  local res, err = httpc:request({
    method = "GET",
    path = "/_web-app-state",
  })
  if err then
    httpc:close()
    return nil, "request error: " .. (err or "")
  elseif res.status ~= 200 then
    httpc:close()
    return nil, "unsuccessful response: " .. (res.status or "")
  end

  local body, body_err = res:read_body()
  if body_err then
    httpc:close()
    return nil, "read body error: " .. (body_err or "")
  end

  local ok, data = xpcall(json_decode, xpcall_error_handler, body)
  if not ok then
    return nil, "failed to parse json: " .. (data or "")
  end

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    httpc:close()
    return nil, "keepalive error: " .. (keepalive_err or "")
  end

  return compress_json_encode(data)
end

local function fetch_envoy_state()
  local data = {}

  local httpc = http.new()
  httpc:set_timeout(2000)

  local connect_ok, connect_err = httpc:connect({
    scheme = "http",
    host = config["envoy"]["admin"]["host"],
    port = config["envoy"]["admin"]["port"],
  })

  if not connect_ok then
    httpc:close()
    return nil, "failed to connect: ".. (connect_err or "")
  end

  local stats_res, stats_err = httpc:request({
    method = "GET",
    path = "/stats?format=json&filter=\\.version_text$",
  })
  if stats_err then
    httpc:close()
    return nil, "envoy admin request error: " .. (stats_err or "")
  end

  local stats_body, stats_body_err = stats_res:read_body()
  if stats_body_err then
    httpc:close()
    return nil, "envoy admin read body error: " .. (stats_body_err or "")
  end

  local stats_json_ok, stats = xpcall(json_decode, xpcall_error_handler, stats_body)
  if not stats_json_ok then
    return nil, "failed to parse json: " .. (stats or "")
  end

  for _, stat in ipairs(stats["stats"]) do
    data[stat["name"]] = stat["value"]
  end

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    httpc:close()
    return nil, "keepalive error: " .. (keepalive_err or "")
  end

  return compress_json_encode(data)
end

local web_app, web_app_err = cache:get("state:web_app", { ttl = state_ttl }, fetch_web_app_state)
if web_app_err then
  ngx.log(ngx.ERR, "error fetching web app state: ", web_app_err)
end

local envoy, envoy_err = cache:get("state:envoy", { ttl = state_ttl }, fetch_envoy_state)
if envoy_err then
  ngx.log(ngx.ERR, "error fetching envoy state: ", envoy_err)
end

local response = {
  file_config_version = json_null_default(active_config["file_version"]),
  db_config_version = json_null_default(active_config["db_version"]),
  api_users_last_fetched_version = json_null_default(jobs_dict:get("api_users_store_last_fetched_version")),
  distributed_rate_limits_last_pulled_at = json_null_default(jobs_dict:get("rate_limit_counters_store_distributed_last_pulled_at")),
  distributed_rate_limits_last_pushed_at = json_null_default(jobs_dict:get("rate_limit_counters_store_distributed_last_pushed_at")),
  web_app = web_app,
  envoy = envoy,
}

ngx.header["Content-Type"] = "application/json"
ngx.say(json_encode(response))
