local cjson = require "cjson"
local inspect = require "inspect"

local response = {
  status = "red",
}

if ngx.shared.apis:get("last_fetched_at") and ngx.shared.api_users:get("last_fetched_at") then
  response["status"] = "yellow"
end

local http = require "resty.http"
local httpc = http.new()

local res, err = httpc:request_uri(config["elasticsearch"]["hosts"][1] .. "/_cluster/health")
if not err and res.body then
  local elasticsearch_health = cjson.decode(res.body)
  if elasticsearch_health["status"] == "green" then
    response["status"] = "green"
  end
end

ngx.say(cjson.encode(response))
