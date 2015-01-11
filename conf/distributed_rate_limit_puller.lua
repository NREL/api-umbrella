local _M = {}

local bson = require "resty-mongol.bson"
local distributed_rate_limit_queue = require "distributed_rate_limit_queue"
local inspect = require "inspect"
local lock = require "resty.lock"
local mongol = require "resty-mongol"
local types = require "pl.types"

local get_utc_date = bson.get_utc_date
local is_empty = types.is_empty

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local delay = 5  -- in seconds
local new_timer = ngx.timer.at

local check
check = function(premature)
  if not premature then
    local ok, err = lock:unlock()
    if not ok then
      --log(ERR, "failed to unlock: ", err)
    end
    local elapsed, err = lock:lock("distributed_rate_limit_puller")

    if not err then
      local conn = mongol()
      conn:set_timeout(1000)

      local ok, err = conn:connect("127.0.0.1", 14001)
      if not ok then
        log(ERR, "connect failed: "..err)
      end

      local db = conn:new_db_handle("api_umbrella")
      local col = db:get_col("rate_limits")

      local last_fetched_time = ngx.shared.stats:get("distributed_last_updated_at") or 0

      local pipeline = {
        {
          ["$match"] = {
            updated_at = {
              ["$gt"] = get_utc_date(last_fetched_time),
            },
            expire_at = {
              ["$gte"] = get_utc_date(ngx.now() * 1000),
            },
          },
        },
        {
          ["$group"] = {
            _id = "$_id.key",
          },
        },
      }
      local r, err = col:aggregate(pipeline)

      local recent_ids = {}
      --for i , v in r:pairs() do
        --table.insert(recent_ids, v["_id"])
      --end

      if not is_empty(recent_ids) then
        local pipeline = {
          {
            ["$match"] = {
              ["_id.key"] = {
                ["$in"] = recent_ids,
              },
              expire_at = {
                ["$gte"] = get_utc_date(ngx.now() * 1000),
              },
            },
          },
          {
            ["$group"] = {
              _id = "$_id.key",
              count = {
                ["$sum"] = "$count",
              },
              expire_at = {
                ["$max"] = "$expire_at",
              },
              max_updated_at = {
                ["$max"] = "$updated_at",
              },
            },
          },
          {
            ["$sort"] = {
              max_updated_at = -1,
            },
          },
        }
        local r = col:aggregate(pipeline)
        local max_updated_at
        for i , v in r:pairs() do
          if i == 1 then
            ngx.shared.stats:set("distributed_last_updated_at", v["max_updated_at"])
          end

          local key = v["_id"]
          local distributed_count = v["count"]
          local local_count = ngx.shared.stats:get(key)
          if not local_count then
            local ttl = (v["expire_at"] - ngx.now() * 1000) / 1000
            ngx.shared.stats:set(key, distributed_count, ttl)
          elseif distributed_count > local_count then
            local incr = distributed_count - local_count
            local count, err = ngx.shared.stats:incr(key, incr)
          end
        end
      end

      conn:set_keepalive(10000, 5)
    end

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
