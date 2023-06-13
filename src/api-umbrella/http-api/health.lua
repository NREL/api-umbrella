local active_config_exists = require("api-umbrella.proxy.stores.active_config_store").exists
local config = require("api-umbrella.utils.load_config")()
local elasticsearch = require "api-umbrella.utils.elasticsearch"
local http = require "resty.http"
local icu_date = require "icu-date-ffi"
local json_encode = require "api-umbrella.utils.json_encode"

local elasticsearch_query = elasticsearch.query
local ngx_var = ngx.var

local function status_response(quick)
  local response = {
    status = "red",
    details = {
      apis_config = "red",
    },
  }

  -- Check to see if the APIs have been loaded.
  if active_config_exists() then
    response["details"]["apis_config"] = "green"
  end

  if quick then
    if response["details"]["apis_config"] == "green" then
      response["status"] = "green"
    end

    return response
  end

  response["details"]["analytics_db"] = "red"
  response["details"]["analytics_db_setup"] = "red"
  response["details"]["web_app"] = "red"

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
    local date = icu_date.new({ zone_id = "UTC" })
    local today = date:format(elasticsearch.partition_date_format)
    local alias = config["elasticsearch"]["index_name_prefix"] .. "-logs-" .. today
    local index = config["elasticsearch"]["index_name_prefix"] .. "-logs-v" .. config["elasticsearch"]["template_version"] .. "-" .. today
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
  elseif res.status == 200 then
    response["details"]["web_app"] = "green"
  end

  -- If everything looks good on the components, then mark our overall status a green.
  --
  -- Note: We accept ElasticSearch being in yellow status as long as the aliases
  -- are setup, since on very first alias creation (but prior to indexing any
  -- content), ElasticSearch seems to get stuck in the yellow status, even though
  -- everything appears operational (but then it becomes green once content
  -- starts indexing).
  if response["details"]["apis_config"] == "green" and (response["details"]["analytics_db"] == "yellow" or response["details"]["analytics_db"] == "green") and response["details"]["analytics_db_setup"] == "green" and response["details"]["web_app"] == "green" then
    response["status"] = "green"
  elseif response["details"]["apis_config"] == "green" then
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
local wait_for_status = ngx_var.arg_wait_for_status
local quick = ngx_var.arg_quick == "true"
if not wait_for_status then
  response = status_response(quick)
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
  local wait_timeout = tonumber(ngx_var.arg_wait_timeout or 50)
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
    response = status_response(quick)

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
