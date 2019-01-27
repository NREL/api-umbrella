local config = require "api-umbrella.proxy.models.file_config"
local http = require "resty.http"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local response = {
  file_config_version = ngx.shared.active_config:get("file_version"),
  db_config_version = ngx.shared.active_config:get("db_version"),
  db_config_last_fetched_at = ngx.shared.active_config:get("db_config_last_fetched_at"),
  api_users_last_fetched_version = ngx.shared.api_users:get("last_fetched_version"),
  distributed_rate_limits_last_pulled_at = ngx.shared.stats:get("distributed_last_pulled_at"),
  distributed_rate_limits_last_pushed_at = ngx.shared.stats:get("distributed_last_pushed_at"),
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
