local active_config_store_poll_for_update = require "api-umbrella.web-app.jobs.active_config_store_poll_for_update"
local active_config_store_refresh_local_cache = require "api-umbrella.web-app.jobs.active_config_store_refresh_local_cache"
local random_seed = require "api-umbrella.utils.random_seed"

-- random_seed may have been been called during the "init" hook as a result of
-- pre-loading modules, but we want to ensure each worker process's random seed
-- is different, so force another call in the init_worker phase.
random_seed()

active_config_store_poll_for_update.spawn()
active_config_store_refresh_local_cache.spawn()
