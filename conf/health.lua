local cjson = require "cjson"
local http = require "resty.http"
local inspect = require "inspect"

local response = {
  status = "red",
  details = {
    apis_config = "red",
    api_users = "red",
    analytics_db = "red",
    analytics_db_setup = "red",
  },
}

-- Check to see if the APIs have been loaded.
if ngx.shared.apis:get("last_fetched_at") then
  response["details"]["apis_config"] = "green"
end

-- Check to see if the users have been loaded.
if ngx.shared.api_users:get("last_fetched_at") then
  response["details"]["api_users"] = "green"
end

-- Check the health of the ElasticSearch cluster
local httpc = http.new()
local res, err = httpc:request_uri(config["elasticsearch"]["hosts"][1] .. "/_cluster/health")
if not err and res.body then
  local elasticsearch_health = cjson.decode(res.body)
  response["details"]["analytics_db"] = elasticsearch_health["status"]
end

-- Check to see if the ElasticSearch index aliases have been setup.
local today = os.date("%Y-%m", ngx.time())
local alias = "api-umbrella-logs-" .. today
local index = "api-umbrella-logs-" .. config["log_template_version"] .. "-" .. today
local res, err = httpc:request_uri(config["elasticsearch"]["hosts"][1] .. "/" .. index .. "/_alias/" .. alias)
if not err and res.body then
  local elasticsearch_alias = cjson.decode(res.body)
  if not elasticsearch_alias["error"] then
    response["details"]["analytics_db_setup"] = "green"
  end
end

-- If everything looks good on the components, then mark our overall status a green.
--
-- Note: We accept ElasticSearch being in yellow status as long as the aliases
-- are setup, since on very first alias creation (but prior to indexing any
-- content), ElasticSearch seems to get stuck in the yellow status, even though
-- everything appears operational (but then it becomes green once content
-- starts indexing).
if response["details"]["apis_config"] == "green" and response["details"]["api_users"] == "green" and (response["details"]["analytics_db"] == "yellow" or response["details"]["analytics_db"] == "green") and response["details"]["analytics_db_setup"] == "green" then
  response["status"] = "green"
elseif response["details"]["apis_config"] == "green" and response["details"]["api_users"] == "green" then
  response["status"] = "yellow"
end

ngx.say(cjson.encode(response))
