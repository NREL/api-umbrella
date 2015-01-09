local _M = {}

local rocks = require "luarocks.loader"
local cmsgpack = require "cmsgpack"
local cjson = require "cjson"
local mp = require "MessagePack"
local std_table = require "std.table"
local utils = require "utils"
local inspect = require "inspect"
local distributed_rate_limit_queue = require "distributed_rate_limit_queue"
local bson = require "resty.mongol.bson"

local delay = 0.05  -- in seconds
local new_timer = ngx.timer.at

local indexes_created = false

function create_indexes(db)
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

local check
check = function(premature)
  if not premature then
    local data = distributed_rate_limit_queue.fetch()
    if not std_table.empty(data) then
      local mongol = require "resty.mongol"

      local conn = mongol:new()
      conn:set_timeout(1000)

      local ok, err = conn:connect("127.0.0.1", 14001)
      if not ok then
        log(ERR, "connect failed: "..err)
      end

      local db = conn:new_db_handle("api_umbrella")
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
            expire_at = bson.get_utc_date(expire_at),
          }
        end

        local upsert = 1
        col:update(selector, update, upsert)
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
