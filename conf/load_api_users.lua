local _M = {}

local inspect = require "inspect"
local cjson = require "cjson"
local http = require "resty.http"
local lock = require "resty.lock"
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

local delay = 1 -- in seconds
local new_timer = ngx.timer.at
local log = ngx.log
local ERR = ngx.ERR

local function do_check()
  local elapsed, err = lock:lock("load_api_users")
  if err then
    return
  end

  local current_fetch_time = ngx.now() * 1000
  local last_fetched_time = api_users:get("last_fetched_at") or current_fetch_time - (60 * 1000)

  local skip = 0
  local page_size = 250
  local err
  repeat
    local httpc = http.new()
    local res, err = httpc:request_uri("http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/api_users", {
      query = {
        extended_json = "true",
        limit = page_size,
        skip = skip,
        sort = "updated_at",
        query = cjson.encode({
          updated_at = {
            ["$gte"] = {
              ["$date"] = last_fetched_time,
            },
            ["$lt"] = {
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
          if result["api_key"] then
            ngx.shared.api_users:delete(result["api_key"])
          end
        end
      end
    end

    skip = skip + page_size
  until is_empty(results)

  if not err then
    api_users:set("last_fetched_at", current_fetch_time)
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
    ngx.log(ngx.ERR, "failed to run api fetch cycle: ", err)
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
