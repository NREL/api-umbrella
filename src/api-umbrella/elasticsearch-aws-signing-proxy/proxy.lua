local config = require("api-umbrella.utils.load_config")()

local username = config["elasticsearch"]["aws_signing_proxy"]["username"]
if not username then
  ngx.say("elasticsearch.aws_signing_proxy.username must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local password = config["elasticsearch"]["aws_signing_proxy"]["password"]
if not password then
  ngx.say("elasticsearch.aws_signing_proxy.password must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local aws_region = config["elasticsearch"]["aws_signing_proxy"]["aws_region"]
if not aws_region then
  ngx.say("elasticsearch.aws_signing_proxy.aws_region must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local aws_access_key_id = config["elasticsearch"]["aws_signing_proxy"]["aws_access_key_id"]
if not aws_access_key_id then
  ngx.say("elasticsearch.aws_signing_proxy.aws_access_key_id must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local aws_secret_access_key = config["elasticsearch"]["aws_signing_proxy"]["aws_secret_access_key"]
if not aws_secret_access_key then
  ngx.say("elasticsearch.aws_signing_proxy.aws_access_key_id must be configured in /etc/api-umbrella/api-umbrella.yml")
  return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local remote_username = ngx.var.remote_user
local remote_password = ngx.var.remote_passwd
if not ngx.var.remote_user or not remote_password then
  ngx.header["WWW-Authenticate"] = 'Basic realm="Restricted"'
  return ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

if remote_username ~= username or remote_password ~= password then
  return ngx.exit(ngx.HTTP_FORBIDDEN)
end

local host = config["elasticsearch"]["aws_signing_proxy"]["aws_host"]
ngx.req.set_header("Host", host)

local signing = require "api-umbrella.utils.aws_signing_v4"
signing.sign_request(aws_region, aws_access_key_id, aws_secret_access_key)
