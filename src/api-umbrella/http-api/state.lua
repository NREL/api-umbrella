local active_config_store = require("api-umbrella.proxy.stores.active_config_store")
local config = require "api-umbrella.proxy.models.file_config"
local http = require "resty.http"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local get_active_config = active_config_store.get
local jobs_dict = ngx.shared.jobs
local refresh_local_active_config_cache = active_config_store.refresh_local_cache
local stats_dict = ngx.shared.stats

-- Refresh cache per request if background polling is disabled.
if config["router"]["active_config"]["refresh_local_cache_interval"] == 0 then
  refresh_local_active_config_cache()
end

local active_config = get_active_config()

local response = {
  file_config_version = json_null_default(active_config["file_version"]),
  db_config_version = json_null_default(active_config["db_version"]),
  api_users_last_fetched_version = json_null_default(jobs_dict:get("api_users_store_last_fetched_version")),
  distributed_rate_limits_last_pulled_at = json_null_default(stats_dict:get("distributed_last_pulled_at")),
  distributed_rate_limits_last_pushed_at = json_null_default(stats_dict:get("distributed_last_pushed_at")),
}

local httpc = http.new()
httpc:set_timeout(1000)
local res, err = httpc:request_uri("http://127.0.0.1:" .. config["web"]["port"] .. "/_web-app-state")
if err then
  ngx.log(ngx.ERR, "failed to fetch web app state: ", err)
elseif res.status == 200 then
  local ok, data = xpcall(json_decode, xpcall_error_handler, res.body)
  if not ok then
    ngx.log(ngx.ERR, "failed to parse web-app-state json: " .. (data or ""))
  else
    response["web_app"] = data
  end
end

ngx.header["Content-Type"] = "application/json"
ngx.say(json_encode(response))
