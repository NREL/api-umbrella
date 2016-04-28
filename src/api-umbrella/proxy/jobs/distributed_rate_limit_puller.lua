local _M = {}

local interval_lock = require "api-umbrella.utils.interval_lock"
local mongo = require "api-umbrella.utils.mongo"
local types = require "pl.types"
local utils = require "api-umbrella.proxy.utils"

local get_packed = utils.get_packed
local is_empty = types.is_empty
local set_packed = utils.set_packed

local delay = 0.25  -- in seconds

local function do_check()
  local current_fetch_time = ngx.now() * 1000
  local last_fetched_timestamp = get_packed(ngx.shared.stats, "distributed_last_fetched_timestamp") or { t = 0, i = 0 }

  local skip = 0
  local page_size = 250
  local success = true
  repeat
    local results, mongo_err = mongo.find("rate_limits", {
      limit = page_size,
      skip = skip,
      sort = "-ts",
      query = {
        ts = {
          ["$gt"] = {
            ["$timestamp"] = last_fetched_timestamp,
          },
        },
      },
    })

    if mongo_err then
      ngx.log(ngx.ERR, "failed to fetch rate limits from mongodb: ", mongo_err)
      success = false
    elseif results then
      for index, result in ipairs(results) do
        if skip == 0 and index == 1 then
          if result["ts"] and result["ts"]["$timestamp"] then
            set_packed(ngx.shared.stats, "distributed_last_fetched_timestamp", result["ts"]["$timestamp"])
          end
        end

        local key = result["_id"]
        local distributed_count = result["count"]
        local local_count = ngx.shared.stats:get(key)
        if not local_count then
          if result["expire_at"] and result["expire_at"]["$date"] then
            local ttl = (result["expire_at"]["$date"] - current_fetch_time) / 1000
            if ttl < 0 then
              ngx.log(ngx.ERR, "distributed_rate_limit_puller ttl unexpectedly less than 0 (key: " .. key .. " ttl: " .. ttl .. ")")
              ttl = 3600
            end

            local _, set_err = ngx.shared.stats:set(key, distributed_count, ttl)
            if set_err then
              ngx.log(ngx.ERR, "failed to set rate limit key", set_err)
            end
          end
        elseif distributed_count > local_count then
          local incr = distributed_count - local_count
          local _, incr_err = ngx.shared.stats:incr(key, incr)
          if incr_err then
            ngx.log(ngx.ERR, "failed to increment rate limit key", incr_err)
          end
        end
      end
    end

    skip = skip + page_size
  until is_empty(results)

  if success then
    ngx.shared.stats:set("distributed_last_pulled_at", current_fetch_time)
  end
end

function _M.spawn()
  interval_lock.repeat_with_mutex('distributed_rate_limit_puller', delay, do_check)
end

return _M
