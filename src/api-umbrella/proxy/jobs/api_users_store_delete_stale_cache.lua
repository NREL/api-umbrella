local repeat_with_mutex = require("api-umbrella.utils.interval_lock").repeat_with_mutex
local delete_stale_cache = require("api-umbrella.proxy.stores.api_users_store").delete_stale_cache

local delay = 1 -- in seconds

local _M = {}

function _M.spawn()
  repeat_with_mutex("api_users_store_delete_stale_cache", delay, delete_stale_cache)
end

return _M
