local _M = {}

local distributed_rate_limit_queue = require "distributed_rate_limit_queue"
local inspect = require "inspect"
local lock = require "resty.lock"
local types = require "pl.types"

local is_empty = types.is_empty

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local delay = 5  -- in seconds
local new_timer = ngx.timer.at


local function do_check()
  local elapsed, err = lock:lock("distributed_rate_limit_puller")
  if err then
    return
  end

  if true then
    return
  end

  local conn = mongol()
  conn:set_timeout(1000)

  local ok, err = conn:connect(config["mongodb"]["host"], config["mongodb"]["port"])
  if not ok then
    ngx.log(ngx.ERR, "connect failed: " .. inspect(err))

    local ok, err = lock:unlock()
    if not ok then
      ngx.log(ngx.ERR, "failed to unlock: ", err)
    end

    return false, "failed to connect to mongodb"
  end

  local db = conn:new_db_handle(config["mongodb"]["database"])
  local col = db:get_col("rate_limits")

  local last_fetched_time = ngx.shared.stats:get("distributed_last_updated_at") or 0

  local page = 1
  repeat
    local httpc = http.new()
    local res, err = httpc:request_uri("http://127.0.0.1:8080/" .. config["mongodb"]["database"] .. "/api_users", {
      query = {
        pagesize = 250,
        page = page,
        filter = cjson.encode({
          {
            ["$match"] = {
              updated_at = {
                ["$gt"] = {
                  ["$date"] = last_fetched_time,
                },
              },
              expire_at = {
                ["$gte"] = {
                  ["$date"] = ngx.now() * 1000,
                },
              },
            },
          },
          {
            ["$group"] = {
              _id = "$_id.key",
            },
          },
        })
      },
    })

    local results = nil
    if not err and res.body then
      local response = cjson.decode(res.body)
      if response and response["_embedded"] and response["_embedded"]["rh:doc"] then
        results = response["_embedded"]["rh:doc"]
        -- ngx.log(ngx.ERR, "RESULTS", inspect(results))
        for index, result in pairs(results) do
          if index == 1 then
            api_users:set("last_updated_at", result["updated_at"]["$date"])
          end

          handle_user_result(result)
        end
      end
    end

    page = page + 1
  until is_empty(results)


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

  local ok, err = lock:unlock()
  if not ok then
    ngx.log(ngx.ERR, "failed to unlock: ", err)
  end
end

local function check(premature)
  if premature then
    return
  end

  local ok, err = pcall(do_check)
  if not ok then
    ngx.log(ngx.ERR, "failed to run backend load cycle: ", err)
  end

  local ok, err = new_timer(delay, check)
  if not ok then
    if err ~= "process exiting" then
      ngx.log(ngx.ERR, "failed to create timer: ", err)
    end

    return
  end
end

function _M.spawn()
  -- local ok, err = new_timer(0, check)
  -- if not ok then
    -- ngx.log(ngx.ERR, "failed to create timer: ", err)
    -- return
  -- end
end

return _M
