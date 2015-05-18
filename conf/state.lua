local cjson = require "cjson"
local inspect = require "inspect"

local response = {
  config_id = ngx.shared.apis:get("config_id"),
  runtime_config_version = ngx.shared.apis:get("version"),
  runtime_config_last_fetched_at = ngx.shared.apis:get("last_fetched_at"),
  api_users_last_fetched_at = ngx.shared.api_users:get("last_fetched_at"),
}

ngx.say(cjson.encode(response))
