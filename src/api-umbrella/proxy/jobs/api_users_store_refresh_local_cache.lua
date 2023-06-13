local refresh_local_cache = require("api-umbrella.proxy.stores.api_users_store").refresh_local_cache

local timer_every = ngx.timer.every

local delay = 1 -- in seconds

local _M = {}

function _M.spawn()
  timer_every(delay, refresh_local_cache)
end

return _M
