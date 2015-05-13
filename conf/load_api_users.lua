local _M = {}
ngx.log(ngx.ERR, "HELLO LOAD API USERS")

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

local function handle_user_result(result)
  local user = clone_select(result, {
    "disabled_at",
    "throttle_by_ip",
  })

  -- Ensure IDs get stored as strings, even if Mongo ObjectIds are in use.
  user["id"] = tostring(result["_id"])

  -- Invert the array of roles into a hashy table for more optimized
  -- lookups (so we can just check if the key exists, rather than
  -- looping over each value).
  if result["roles"] then
    user["roles"] = invert(result["roles"])
  end

  if user["throttle_by_ip"] == false then
    user["throttle_by_ip"] = nil
  end

  if result["settings"] then
    user["settings"] = clone_select(result["settings"], {
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

  set_packed(api_users, result["api_key"], user)
end

local function do_check()
  local elapsed, err = lock:lock("load_api_users")
  if err then
    return
  end

  local last_fetched_time = api_users:get("last_updated_at") or 0

  local skip = 0
  local page_size = 250
  local err
  repeat
    local httpc = http.new()
    local res, err = httpc:request_uri("http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["database"] .. "/api_users", {
      query = {
        extended_json = "true",
        limit = page_size,
        skip = skip,
        query = cjson.encode({
          updated_at = {
            ["$gt"] = {
              ["$date"] = last_fetched_time,
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
        ngx.log(ngx.ERR, "RESULTS", inspect(results))
        for index, result in pairs(results) do
          if index == 1 then
            api_users:set("last_updated_at", result["updated_at"]["$date"])
          end

          handle_user_result(result)
        end
      end
    end

    skip = skip + page_size
  until is_empty(results)

  if not err then
    api_users:set("last_fetched_at", ngx.now())
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
