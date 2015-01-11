local iputils = require "resty.iputils"

-- Cache IP to binary lookup results (used internally in ip_in_cidr). Cache the
-- last 1,000 IPs seen (around 256KB memory per worker).
iputils.enable_lrucache(1000)

local load_apis = require "load_apis"
load_apis.spawn()

local load_backends = require "load_backends"
load_backends.spawn()

local load_api_users = require "load_api_users"
load_api_users.spawn()

local distributed_rate_limit_puller = require "distributed_rate_limit_puller"
distributed_rate_limit_puller.spawn()

local distributed_rate_limit_pusher = require "distributed_rate_limit_pusher"
distributed_rate_limit_pusher.spawn()
