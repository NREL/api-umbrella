local elasticsearch_query = require("api-umbrella.utils.elasticsearch").query
local http = require "resty.http"
local json_encode = require "api-umbrella.utils.json_encode"

local function status_response()
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
  local res, err = elasticsearch_query("/_cluster/health")
  if err then
    ngx.log(ngx.ERR, "failed to fetch cluster health from elasticsearch: ", err)
  elseif res.body_json then
    local elasticsearch_health = res.body_json
    response["details"]["analytics_db"] = elasticsearch_health["status"]

    -- Check to see if the ElasticSearch index aliases have been setup.
    local today = os.date("!%Y-%m", ngx.time())
    local alias = "api-umbrella-logs-" .. today
    local index = "api-umbrella-logs-v" .. config["elasticsearch"]["template_version"] .. "-" .. today
    res, err = elasticsearch_query("/" .. index .. "/_alias/" .. alias)
    if err then
      ngx.log(ngx.ERR, "failed to fetch elasticsearch alias details: ", err)
    elseif res.body_json then
      local elasticsearch_alias = res.body_json
      if not elasticsearch_alias["error"] then
        response["details"]["analytics_db_setup"] = "green"
      end
    end
  end

  res, err = httpc:request_uri("http://127.0.0.1:" .. config["web"]["port"] .. "/_web-app-health")
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

  return response
end

-- By default, check the health status and return it immediately.
--
-- If a "wait_for_status" query param is passed in, then loop until this status
-- becomes true, or the request times out (defaults to 50 seconds).
--
-- "wait_for_status" can be "green", "yellow", or "red". The request will wait
-- until this status *or better* is met. green > yellow > red, so
-- wait_for_status=yellow will return if the status is actually yellow.
local response
local wait_for_status = ngx.var.arg_wait_for_status
if not wait_for_status then
  response = status_response()
else
  -- Validate the wait_for_status param.
  if wait_for_status ~= "green" and wait_for_status ~= "yellow" and wait_for_status ~= "red" then
    ngx.status = 422
    ngx.header["Content-Type"] = "application/json"
    ngx.say(json_encode({
      error = "Invalid wait_for_status argument (" .. (tostring(wait_for_status) or "") .. ")",
    }))
    return ngx.exit(ngx.HTTP_OK)
  end

  -- Validate the wait_timeout param (defaults to 50).
  local wait_timeout = tonumber(ngx.var.arg_wait_timeout or 50)
  if not wait_timeout then
    ngx.status = 422
    ngx.header["Content-Type"] = "application/json"
    ngx.say(json_encode({
      error = "Invalid wait_timeout argument (" .. (tostring(wait_timeout) or "") .. ")",
    }))
    return ngx.exit(ngx.HTTP_OK)
  end

  -- Loop until the status is met or we timeout.
  local timeout_at = ngx.now() + wait_timeout
  while true do
    response = status_response()

    -- Break out of loop if the status (or better) is met.
    local status = response["status"]
    if wait_for_status == status then
      break
    elseif wait_for_status == "yellow" and status == "green" then
      break
    elseif wait_for_status == "red" and (status == "green" or status == "yellow") then
      break
    end

    -- If we've timed out, still return the last status in the response, but
    -- with an HTTP error code to indicate it wasn't met.
    if ngx.now() > timeout_at then
      ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
      break
    end

    ngx.sleep(0.5)
  end
end

-- Return an error HTTP status code if the status is red.
if response["status"] == "red" then
  ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
end

ngx.header["Content-Type"] = "application/json"
ngx.say(json_encode(response))
