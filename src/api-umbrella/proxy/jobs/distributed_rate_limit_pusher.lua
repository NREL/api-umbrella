local _M = {}

local cjson = require "cjson"
local distributed_rate_limit_queue = require "api-umbrella.proxy.distributed_rate_limit_queue"
local http = require "resty.http"
local types = require "pl.types"

local is_empty = types.is_empty

local delay = 0.25  -- in seconds
local new_timer = ngx.timer.at

local indexes_created = false

local function create_indexes()
  if not indexes_created then
    local httpc = http.new()
    local _, err = httpc:request_uri("http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/system.indexes", {
      method = "POST",
      headers = {
        ["Content-Type"] = "application/json",
      },
      query = {
        extended_json = "true",
      },

      body = cjson.encode({
        ns = config["mongodb"]["_database"] .. ".rate_limits",
        key = {
          ts = -1,
        },
        name = "ts",
        background = true,
      })
    })
    if err then
      ngx.log(ngx.ERR, "failed to create mongodb ts index: ", err)
    end

    httpc = http.new()
    _, err = httpc:request_uri("http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/system.indexes", {
      method = "POST",
      headers = {
        ["Content-Type"] = "application/json",
      },
      query = {
        extended_json = "true",
      },
      body = cjson.encode({
        ns = config["mongodb"]["_database"] .. ".rate_limits",
        key = {
          expire_at = 1,
        },
        name = "expire_at",
        expireAfterSeconds = 0,
        background = true,
      })
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
    local update = {
      ["$currentDate"] = {
        ts = { ["$type"] = "timestamp" },
      },
      ["$inc"] = {
        count = count,
      },
      ["$setOnInsert"] = {
        expire_at = ngx.now() * 1000 + 60000,
      },
    }

    local httpc = http.new()
    local _, err = httpc:request_uri("http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/rate_limits/" .. key, {
      method = "PUT",
      headers = {
        ["Content-Type"] = "application/json",
      },
      query = {
        extended_json = "true",
      },
      body = cjson.encode(update),
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
