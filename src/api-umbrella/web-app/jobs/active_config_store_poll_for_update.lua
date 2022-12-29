local repeat_with_mutex = require("api-umbrella.utils.interval_lock").repeat_with_mutex
local poll_for_update = require("api-umbrella.web-app.stores.active_config_store").poll_for_update

local delay = 1 -- in seconds

local _M = {}

function _M.spawn()
  repeat_with_mutex("active_config_store_poll_for_update", delay, poll_for_update)
end

return _M
