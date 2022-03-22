local active_config = require "api-umbrella.proxy.models.active_config"
local load_db_config = require "api-umbrella.proxy.jobs.load_db_config"
local random_seed = require "api-umbrella.utils.random_seed"

-- random_seed may have been been called during the "init" hook as a result of
-- pre-loading modules, but we want to ensure each worker process's random seed
-- is different, so force another call in the init_worker phase.
random_seed()

load_db_config.spawn(active_config.web_set)
