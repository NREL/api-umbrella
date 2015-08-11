local cjson = require "cjson"
local inspect = require "inspect"

local response = {
  file_config_version = ngx.shared.active_config:get("file_version"),
  db_config_version = ngx.shared.active_config:get("db_version"),
  db_config_last_fetched_at = ngx.shared.active_config:get("db_config_last_fetched_at"),
  api_users_last_fetched_at = ngx.shared.api_users:get("last_fetched_at"),
}

ngx.say(cjson.encode(response))
