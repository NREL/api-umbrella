local config = require("api-umbrella.utils.load_config")()
local refresh_local_cache = require("api-umbrella.proxy.stores.active_config_store").refresh_local_cache

local timer_every = ngx.timer.every

local delay = config["router"]["active_config"]["refresh_local_cache_interval"] -- in seconds

local _M = {}

function _M.spawn()
  if delay > 0 then
    timer_every(delay, refresh_local_cache)
  end
end

return _M
