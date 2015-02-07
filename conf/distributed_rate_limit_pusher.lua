local _M = {}

local bson = require "resty-mongol.bson"
local distributed_rate_limit_queue = require "distributed_rate_limit_queue"
local inspect = require "inspect"
local mongol = require "resty-mongol"
local types = require "pl.types"
local utils = require "utils"

local get_utc_date = bson.get_utc_date
local is_empty = types.is_empty

local delay = 0.05  -- in seconds
local new_timer = ngx.timer.at

local indexes_created = false

local function create_indexes(db)
  if not indexes_created then
    local col = db:get_col("system.indexes")
    local docs = {
      {
        ns = "api_umbrella.rate_limits",
        key = {
          updated_at = -1,
        },
        name = "updated_at",
        background = true,
      },
      {
        ns = "api_umbrella.rate_limits",
        key = {
          expire_at = 1,
        },
        name = "expire_at",
        expireAfterSeconds = 0,
        background = true,
      },
    }

    local continue_on_error = 1
    local safe = 1
    result, err = col:insert(docs, continue_on_error, safe)
    indexes_created = true
  end
end

local function do_check()
  local data = distributed_rate_limit_queue.fetch()
  if is_empty(data) then
    return
  end

  local conn = mongol()
  conn:set_timeout(1000)

  local ok, err = conn:connect("127.0.0.1", 27017)
  if not ok then
    log(ERR, "connect failed: "..err)
  end

  local db = conn:new_db_handle("api_umbrella_test")
  create_indexes(db)

  local col = db:get_col("rate_limits")

  for key, expire_at in pairs(data) do
    local selector = {
      _id = {
        key = key,
        node = MASTER_NODE_ID,
      },
    }
    local update = {
      ["$currentDate"] = {
        updated_at = true,
      },
      ["$inc"] = {
        count = 1,
      },
    }

    if expire_at and expire_at > 0 then
      update["$setOnInsert"] = {
        expire_at = get_utc_date(expire_at),
      }
    end

    local upsert = 1
    col:update(selector, update, upsert)
  end

  conn:set_keepalive(10000, 5)
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
    log(ERR, "failed to create timer: ", err)
    return
  end
end

return _M
