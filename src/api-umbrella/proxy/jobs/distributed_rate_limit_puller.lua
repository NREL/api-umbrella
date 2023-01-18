local repeat_with_mutex = require("api-umbrella.utils.interval_lock").repeat_with_mutex
local distributed_pull = require("api-umbrella.proxy.stores.rate_limit_counters_store").distributed_pull

local delay = 0.25  -- in seconds

local _M = {}

function _M.spawn()
  repeat_with_mutex("rate_limit_counters_store_distributed_pull", delay, distributed_pull)
end

return _M
