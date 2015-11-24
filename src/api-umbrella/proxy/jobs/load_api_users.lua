local _M = {}

local interval_lock = require "api-umbrella.utils.interval_lock"
local mongo = require "api-umbrella.utils.mongo"
local types = require "pl.types"
local utils = require "api-umbrella.proxy.utils"

local get_packed = utils.get_packed
local is_empty = types.is_empty
local set_packed = utils.set_packed

local api_users = ngx.shared.api_users

local delay = 1 -- in seconds

local function do_check()
  local current_fetch_time = ngx.now() * 1000
  local last_fetched_timestamp = get_packed(api_users, "distributed_last_fetched_timestamp") or { t = math.floor((current_fetch_time - 60 * 1000) / 1000), i = 0 }

  local skip = 0
  local page_size = 250
  local success = true
  repeat
    local results, mongo_err = mongo.find("api_users", {
      limit = page_size,
      skip = skip,
      sort = "updated_at",
      query = {
        ts = {
          ["$gt"] = {
            ["$timestamp"] = last_fetched_timestamp,
          },
        },
      },
    })

    if mongo_err then
      ngx.log(ngx.ERR, "failed to fetch users from mongodb: ", mongo_err)
      success = false
    elseif results then
      for index, result in ipairs(results) do
        if skip == 0 and index == 1 then
          if result["ts"] and result["ts"]["$timestamp"] then
            set_packed(api_users, "distributed_last_fetched_timestamp", result["ts"]["$timestamp"])
          end
        end

        if result["api_key"] then
          ngx.shared.api_users:delete(result["api_key"])
        end
      end
    end

    skip = skip + page_size
  until is_empty(results)

  if success then
    api_users:set("last_fetched_at", current_fetch_time)
  end
end

function _M.spawn()
  interval_lock.repeat_with_mutex('load_api_users', delay, do_check)
end

return _M
