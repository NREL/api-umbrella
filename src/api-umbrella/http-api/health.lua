local cjson = require "cjson"
local http = require "resty.http"

local response = {
  status = "red",
  details = {
    apis_config = "red",
    api_users = "red",
    analytics_db = "red",
    analytics_db_setup = "red",
    web_app = "red",
  },
}

-- Check to see if the APIs have been loaded.
if ngx.shared.active_config:get("db_config_last_fetched_at") then
  response["details"]["apis_config"] = "green"
end

-- Check to see if the users have been loaded.
if ngx.shared.api_users:get("last_fetched_at") then
  response["details"]["api_users"] = "green"
end

local httpc = http.new()
httpc:set_timeout(3000)

-- Check the health of the ElasticSearch cluster
local res, err = httpc:request_uri(config["elasticsearch"]["hosts"][1] .. "/_cluster/health")
if err then
  ngx.log(ngx.ERR, "failed to fetch cluster health from elasticsearch: ", err)
elseif res.body then
  local elasticsearch_health = cjson.decode(res.body)
  response["details"]["analytics_db"] = elasticsearch_health["status"]

  -- Check to see if the ElasticSearch index aliases have been setup.
  local today = os.date("%Y-%m", ngx.time())
  local alias = "api-umbrella-logs-" .. today
  local index = "api-umbrella-logs-" .. config["log_template_version"] .. "-" .. today
  res, err = httpc:request_uri(config["elasticsearch"]["hosts"][1] .. "/" .. index .. "/_alias/" .. alias)
  if err then
    ngx.log(ngx.ERR, "failed to fetch elasticsearch alias details: ", err)
  elseif res.body then
    local elasticsearch_alias = cjson.decode(res.body)
    if not elasticsearch_alias["error"] then
      response["details"]["analytics_db_setup"] = "green"
    end
  end
end

res, err = httpc:request_uri("http://127.0.0.1:" .. config["web"]["port"] .. "/admin/")
if err then
  ngx.log(ngx.ERR, "failed to fetch web app: ", err)
elseif res.body then
  response["details"]["web_app"] = "green"
end

-- If everything looks good on the components, then mark our overall status a green.
--
-- Note: We accept ElasticSearch being in yellow status as long as the aliases
-- are setup, since on very first alias creation (but prior to indexing any
-- content), ElasticSearch seems to get stuck in the yellow status, even though
-- everything appears operational (but then it becomes green once content
-- starts indexing).
if response["details"]["apis_config"] == "green" and response["details"]["api_users"] == "green" and (response["details"]["analytics_db"] == "yellow" or response["details"]["analytics_db"] == "green") and response["details"]["analytics_db_setup"] == "green" and response["details"]["web_app"] == "green" then
  response["status"] = "green"
elseif response["details"]["apis_config"] == "green" and response["details"]["api_users"] == "green" then
  response["status"] = "yellow"
end

ngx.say(cjson.encode(response))
