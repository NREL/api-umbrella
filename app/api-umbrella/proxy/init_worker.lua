local load_apis = require "api-umbrella.proxy.load_apis"
local load_api_users = require "api-umbrella.proxy.load_api_users"
local distributed_rate_limit_puller = require "api-umbrella.proxy.distributed_rate_limit_puller"
local distributed_rate_limit_pusher = require "api-umbrella.proxy.distributed_rate_limit_pusher"
local elasticsearch_setup = require "api-umbrella.proxy.elasticsearch_setup"
local resolve_backend_dns = require "api-umbrella.proxy.resolve_backend_dns"

load_apis.spawn()
load_api_users.spawn()
resolve_backend_dns.spawn()
distributed_rate_limit_puller.spawn()
distributed_rate_limit_pusher.spawn()
elasticsearch_setup.spawn()

local dyups = require "ngx.dyups"
local inspect = require "inspect"
local status, rv = dyups.update("test", [[server 127.0.0.1:8088;]]);
