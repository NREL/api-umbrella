local cjson = require "cjson"
local inspect = require "inspect"

local response = {
  status = "red",
  details = {
    apis_config = "red",
    api_users = "red",
    analytics_db = "red",
  },
}

if ngx.shared.apis:get("last_fetched_at") then
  response["details"]["apis_config"] = "green"
end

if ngx.shared.api_users:get("last_fetched_at") then
  response["details"]["api_users"] = "green"
end

local http = require "resty.http"
local httpc = http.new()

local res, err = httpc:request_uri(config["elasticsearch"]["hosts"][1] .. "/_cluster/health")
if not err and res.body then
  local elasticsearch_health = cjson.decode(res.body)
  response["details"]["analytics_db"] = elasticsearch_health["status"]
end

if response["details"]["apis_config"] == "green" and response["details"]["api_users"] == "green" and response["details"]["analytics_db"] == "green" then
  response["status"] = "green"
elseif response["details"]["apis_config"] == "green" and response["details"]["api_users"] == "green" then
  response["status"] = "yellow"
end

ngx.say(cjson.encode(response))
