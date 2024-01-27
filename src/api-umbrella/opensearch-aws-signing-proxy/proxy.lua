local ngx_exit = ngx.exit
local ngx_say = ngx.say
local ngx_var = ngx.var
local req_set_header = ngx.req.set_header

local config = require("api-umbrella.utils.load_config")()

local username = config["opensearch"]["aws_signing_proxy"]["username"]
if not username then
  ngx_say("opensearch.aws_signing_proxy.username must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx_exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local password = config["opensearch"]["aws_signing_proxy"]["password"]
if not password then
  ngx_say("opensearch.aws_signing_proxy.password must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx_exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local aws_region = config["opensearch"]["aws_signing_proxy"]["aws_region"]
if not aws_region then
  ngx_say("opensearch.aws_signing_proxy.aws_region must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx_exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local aws_access_key_id = config["opensearch"]["aws_signing_proxy"]["aws_access_key_id"]
if not aws_access_key_id then
  ngx_say("opensearch.aws_signing_proxy.aws_access_key_id must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx_exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local aws_secret_access_key = config["opensearch"]["aws_signing_proxy"]["aws_secret_access_key"]
if not aws_secret_access_key then
  ngx_say("opensearch.aws_signing_proxy.aws_access_key_id must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx_exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local remote_username = ngx_var.remote_user
local remote_password = ngx_var.remote_passwd
if not remote_username or not remote_password then
  ngx.header["WWW-Authenticate"] = 'Basic realm="Restricted"'
  return ngx_exit(ngx.HTTP_UNAUTHORIZED)
end

if remote_username ~= username or remote_password ~= password then
  return ngx_exit(ngx.HTTP_FORBIDDEN)
end

local host = config["opensearch"]["aws_signing_proxy"]["aws_host"]
req_set_header("Host", host)

local signing = require "api-umbrella.utils.aws_signing_v4"
signing.sign_request(aws_region, aws_access_key_id, aws_secret_access_key)
