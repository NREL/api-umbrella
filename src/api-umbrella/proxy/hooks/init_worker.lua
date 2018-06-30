local distributed_rate_limit_puller = require "api-umbrella.proxy.jobs.distributed_rate_limit_puller"
local distributed_rate_limit_pusher = require "api-umbrella.proxy.jobs.distributed_rate_limit_pusher"
local elasticsearch_setup = require "api-umbrella.proxy.jobs.elasticsearch_setup"
local load_api_users = require "api-umbrella.proxy.jobs.load_api_users"
local load_db_config = require "api-umbrella.proxy.jobs.load_db_config"
local random_seed = require "api-umbrella.utils.random_seed"
local seed_database = require "api-umbrella.proxy.startup.seed_database"

-- random_seed may have been been called during the "init" hook as a result of
-- pre-loading modules, but we want to ensure each worker process's random seed
-- is different, so force another call in the init_worker phase.
random_seed()

load_db_config.spawn()
load_api_users.spawn()
distributed_rate_limit_puller.spawn()
distributed_rate_limit_pusher.spawn()
elasticsearch_setup.spawn()
seed_database()
