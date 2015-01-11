local _M = {}

local inspect = require "inspect"
local lock = require "resty.lock"
local mongol = require "resty-mongol"
local std_table = require "std.table"
local types = require "pl.types"
local utils = require "utils"

local cache_computed_settings = utils.cache_computed_settings
local clone_select = std_table.clone_select
local invert = std_table.invert
local is_empty = types.is_empty
local set_packed = utils.set_packed

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local api_users = ngx.shared.api_users

local delay = 3  -- in seconds
local new_timer = ngx.timer.at
local log = ngx.log
local ERR = ngx.ERR

local check
check = function(premature)
  if not premature then
    local ok, err = lock:unlock()
    if not ok then
      --log(ERR, "failed to unlock: ", err)
    end
    local elapsed, err = lock:lock("load_api_users")

    if not err then
      local conn = mongol()
      conn:set_timeout(1000)

      local ok, err = conn:connect("127.0.0.1", 14001)
      if not ok then
        log(ERR, "connect failed: "..err)
      end

      local db = conn:new_db_handle("api_umbrella")
      local col = db:get_col("api_users")

      local r = col:find({})
      for i , v in r:pairs() do
        local user = clone_select(v, {
          "disabled_at",
          "throttle_by_ip",
        })

        user["id"] = v["_id"]

        -- Invert the array of roles into a hashy table for more optimized
        -- lookups (so we can just check if the key exists, rather than
        -- looping over each value).
        if v["roles"] then
          user["roles"] = invert(v["roles"])
        end

        if user["throttle_by_ip"] == false then
          user["throttle_by_ip"] = nil
        end

        if v["settings"] then
          user["settings"] = clone_select(v["settings"], {
            "allowed_ips",
            "allowed_referers",
            "rate_limit_mode",
            "rate_limits",
          })

          if is_empty(user["settings"]) then
            user["settings"] = nil
          else
            cache_computed_settings(user["settings"])
          end
        end

        set_packed(api_users, v["api_key"], user)
      end

      conn:set_keepalive(10000, 5)
    end
    -- do the health check or other routine work
    local ok, err = new_timer(delay, check)
    if not ok then
      log(ERR, "failed to create timer: ", err)
      return
    end
  end
end

function _M.spawn()
  local ok, err = new_timer(0, check)
  if not ok then
    log(ERR, "failed to create timer: ", err)
    return
  end
end

return _M
