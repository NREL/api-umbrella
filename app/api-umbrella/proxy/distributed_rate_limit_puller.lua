local _M = {}

local cjson = require "cjson"
local distributed_rate_limit_queue = require "api-umbrella.proxy.distributed_rate_limit_queue"
local http = require "resty.http"
local inspect = require "inspect"
local lock = require "resty.lock"
local types = require "pl.types"

local is_empty = types.is_empty

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local delay = 0.25  -- in seconds
local new_timer = ngx.timer.at

local function do_check()
  local elapsed, err = lock:lock("distributed_rate_limit_puller")
  if err then
    return
  end

  local current_fetch_time = ngx.now() * 1000
  local last_fetched_time = ngx.shared.stats:get("distributed_last_fetched_at") or 0

  local skip = 0
  local page_size = 250
  local err
  repeat
    local httpc = http.new()
    local res, err = httpc:request_uri("http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/rate_limits", {
      query = {
        extended_json = "true",
        limit = page_size,
        skip = skip,
        query = cjson.encode({
          updated_at = {
            ["$gte"] = {
              ["$date"] = last_fetched_time,
            },
            ["$lt"] = {
              ["$date"] = current_fetch_time,
            },
          },
          expire_at = {
            ["$gte"] = {
              ["$date"] = current_fetch_time,
            },
          },
        }),
      },
    })

    local results = nil
    if not err and res.body then
      local response = cjson.decode(res.body)
      if response and response["data"] then
        results = response["data"]
        for _, result in ipairs(results) do
          local key = result["_id"]
          local distributed_count = result["count"]
          local local_count = ngx.shared.stats:get(key)
          if not local_count then
            if result["expire_at"] and result["expire_at"]["$date"] then
              local ttl = (result["expire_at"]["$date"] - current_fetch_time) / 1000
              ngx.shared.stats:set(key, distributed_count, ttl)
            end
          elseif distributed_count > local_count then
            local incr = distributed_count - local_count
            local count, err = ngx.shared.stats:incr(key, incr)
          end
        end
      end
    end

    skip = skip + page_size
  until is_empty(results)

  if not err then
    ngx.shared.stats:set("distributed_last_fetched_at", current_fetch_time)
  end

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
  local ok, err = new_timer(0, check)
  if not ok then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
    return
  end
end

return _M
