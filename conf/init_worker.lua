local load_apis = require "load_apis"
local load_api_users = require "load_api_users"
local distributed_rate_limit_puller = require "distributed_rate_limit_puller"
local distributed_rate_limit_pusher = require "distributed_rate_limit_pusher"
local elasticsearch_setup = require "elasticsearch_setup"
local resolve_backend_dns = require "resolve_backend_dns"

load_apis.spawn()
load_api_users.spawn()
resolve_backend_dns.spawn()
distributed_rate_limit_puller.spawn()
distributed_rate_limit_pusher.spawn()
elasticsearch_setup.spawn()

local dyups = require "ngx.dyups"
local inspect = require "inspect"
local status, rv = dyups.update("test", [[server 127.0.0.1:8088;]]);
