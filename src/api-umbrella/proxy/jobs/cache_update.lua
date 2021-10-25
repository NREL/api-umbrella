local _M = {}

local api_users_cache = require("api-umbrella.proxy.user_store").cache

local delay = 1 -- in seconds

local function do_check()
  local _, update_err = api_users_cache:update()
  if update_err then
    ngx.log(ngx.ERR, "api_users cache update failed: ", update_err)
  end
end

function _M.spawn()
  ngx.timer.every(delay, do_check)
end

return _M
