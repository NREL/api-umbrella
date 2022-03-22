local active_config = require "api-umbrella.proxy.models.active_config"
local api_user_cache_expire = require "api-umbrella.proxy.jobs.api_user_cache_expire"
local cache_update = require "api-umbrella.proxy.jobs.cache_update"
local db_expirations = require "api-umbrella.proxy.jobs.db_expirations"
local distributed_rate_limit_puller = require "api-umbrella.proxy.jobs.distributed_rate_limit_puller"
local distributed_rate_limit_pusher = require "api-umbrella.proxy.jobs.distributed_rate_limit_pusher"
local elasticsearch_setup = require "api-umbrella.proxy.jobs.elasticsearch_setup"
local load_db_config = require "api-umbrella.proxy.jobs.load_db_config"
local random_seed = require "api-umbrella.utils.random_seed"
local seed_database = require "api-umbrella.proxy.startup.seed_database"

-- random_seed may have been been called during the "init" hook as a result of
-- pre-loading modules, but we want to ensure each worker process's random seed
-- is different, so force another call in the init_worker phase.
random_seed()

load_db_config.spawn(active_config.proxy_set)
api_user_cache_expire.spawn()
cache_update.spawn()
db_expirations.spawn()
distributed_rate_limit_puller.spawn()
distributed_rate_limit_pusher.spawn()
elasticsearch_setup.spawn()
seed_database.spawn()
