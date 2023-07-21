local get_active_config = require("api-umbrella.proxy.stores.active_config_store").get
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"

local ngx_exit = ngx.exit
local ngx_header = ngx.header
local ngx_say = ngx.say
local req_get_body_data = ngx.req.get_body_data
local req_read_body = ngx.req.read_body

local function handle_not_modified(config)
  req_read_body()
  local body = req_get_body_data()
  local data = json_decode(body)

  if data["version_info"] == config["version_info"] then
    return ngx_exit(ngx.HTTP_NOT_MODIFIED)
  end
end

local function handle_config(config_name)
  local active_config = get_active_config()
  local config = active_config["envoy_xds"][config_name]
  handle_not_modified(config)

  ngx_header["Content-Type"] = "application/json"
  ngx_say(json_encode(config))
  return ngx_exit(ngx.HTTP_OK)
end

local function clusters()
  return handle_config("clusters")
end

local function listeners()
  return handle_config("listeners")
end

local function routes()
  return handle_config("routes")
end

local function require_method(required_method)
  local method = ngx.req.get_method()
  if method ~= required_method then
    return ngx_exit(ngx.HTTP_NOT_ALLOWED)
  end
end

local request_uri = ngx.var.request_uri
if request_uri == "/v3/discovery:clusters" then
  require_method("POST")
  clusters()
elseif request_uri == "/v3/discovery:listeners" then
  require_method("POST")
  listeners()
elseif request_uri == "/v3/discovery:routes" then
  require_method("POST")
  routes()
else
  ngx_exit(ngx.HTTP_NOT_FOUND)
end
