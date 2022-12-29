local db_expirations = require "api-umbrella.auto-ssl.jobs.db_expirations"
local random_seed = require "api-umbrella.utils.random_seed"

-- random_seed may have been been called during the "init" hook as a result of
-- pre-loading modules, but we want to ensure each worker process's random seed
-- is different, so force another call in the init_worker phase.
random_seed()

auto_ssl:init_worker()
db_expirations.spawn()
