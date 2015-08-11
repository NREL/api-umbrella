local cjson = require "cjson"
local http = require "resty.http"
local inspect = require "inspect"
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"

local base_url = "http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/config_versions"

local _M = {}

local function build_url(last_fetched_version)
  if not last_fetched_version then
    last_fetched_version = 0
  end

  local url = base_url .. "?" .. ngx.encode_args({
    extended_json = "true",
    limit = 1,
    sort = "-version",
    query = cjson.encode({
      version = {
        ["$gt"] = {
          ["$date"] = last_fetched_version,
        },
      },
    }),
  })

  return url
end

local function make_request(url)
  local httpc = http.new()
  local res, err = httpc:request_uri(url)

  local body
  if res then
    body = res.body
  end

  return body, err
end

local function build_result(body)
  local result = {}
  local response = cjson.decode(body)
  if response and response["data"] and response["data"] and response["data"][1] then
    local data = response["data"][1]
    if data and data["config"] then
      nillify_json_nulls(data["config"])

      if data["config"]["apis"] then
        result["apis"] = data["config"]["apis"]
      end

      if data["config"]["website_backends"] then
        result["website_backends"] = data["config"]["website_backends"]
      end
    end

    result["version"] = data["version"]["$date"]
  end

  return result
end

function _M.fetch(last_fetched_version)
  local url = build_url(last_fetched_version)
  local body, err = make_request(url)

  if err then
    return nil, err
  else
    local result = build_result(body)
    return result, nil
  end
end

return _M
