local _M = {}

local array_last = require "api-umbrella.utils.array_last"
local distributed_rate_limit_queue = require "api-umbrella.proxy.distributed_rate_limit_queue"
local mongo = require "api-umbrella.utils.mongo"
local plutils = require "pl.utils"
local types = require "pl.types"

local is_empty = types.is_empty
local split = plutils.split

local delay = 0.25  -- in seconds
local new_timer = ngx.timer.at

local indexes_created = false

local function create_indexes()
  if not indexes_created then
    local _, err = mongo.create("system.indexes", {
      ns = config["mongodb"]["_database"] .. ".rate_limits",
      key = {
        ts = -1,
      },
      name = "ts",
      background = true,
    })
    if err then
      ngx.log(ngx.ERR, "failed to create mongodb ts index: ", err)
    end

    _, err = mongo.create("system.indexes", {
      ns = config["mongodb"]["_database"] .. ".rate_limits",
      key = {
        expire_at = 1,
      },
      name = "expire_at",
      expireAfterSeconds = 0,
      background = true,
    })
    if err then
      ngx.log(ngx.ERR, "failed to create mongodb expire_at index: ", err)
    end

    indexes_created = true
  end
end

local function do_check()
  create_indexes()

  local current_save_time = ngx.now() * 1000

  local data = distributed_rate_limit_queue.pop()
  if is_empty(data) then
    return
  end

  local success = true
  for key, count in pairs(data) do
    local key_parts = split(key, ":", true)
    local duration = tonumber(key_parts[2])
    local bucket_start_time = tonumber(array_last(key_parts))
    local _, err = mongo.update("rate_limits", key, {
      ["$currentDate"] = {
        ts = { ["$type"] = "timestamp" },
      },
      ["$inc"] = {
        count = count,
      },
      ["$setOnInsert"] = {
        -- Set this key to automatically expire after the bucket's duration,
        -- plus 60 seconds as a small buffer.
        expire_at = {
          ["$date"] = { ["$numberLong"] = tostring(bucket_start_time + duration + 60000) },
        },
      },
    })
    if err then
      ngx.log(ngx.ERR, "failed to update rate limits in mongodb: ", err)
      success = false
    end
  end

  if success then
    ngx.shared.stats:set("distributed_last_pushed_at", current_save_time)
  end
end

-- Repeat calls to do_check() inside each worker on the specified interval
-- (every 0.25 seconds).
--
-- We don't use interval_lock.repeat_with_mutex() here like most of our other
-- background jobs, because in this job's case we're pushing local worker data
-- into the database. In this case, we don't want a mutex across workers, since
-- we want each worker to operate independently and fire every 0.25 seconds to
-- push it's local data to the database. With a mutex, certain workers may not
-- be called for longer periods of time causing the local data to build up and
-- not be synced as frequently as we expect.
local function check(premature)
  if premature then
    return
  end

  local ok, err = pcall(do_check)
  if not ok then
    ngx.log(ngx.ERR, "failed to run backend load cycle: ", err)
  end

  ok, err = new_timer(delay, check)
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
