local config = require "api-umbrella.proxy.models.file_config"
local refresh_local_cache = require("api-umbrella.proxy.stores.active_config_store").refresh_local_cache

local delay = config["router"]["active_config"]["refresh_local_cache_interval"] -- in seconds

local _M = {}

function _M.spawn()
  if delay > 0 then
    ngx.timer.every(delay, refresh_local_cache)
  end
end

return _M
