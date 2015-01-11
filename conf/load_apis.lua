local _M = {}

local api_store = require "api_store"
local bson = require "resty-mongol.bson"
local inspect = require "inspect"
local lock = require "resty.lock"
local mongol = require "resty-mongol"
local utils = require "utils"

local cache_computed_settings = utils.cache_computed_settings
local get_utc_date = bson.get_utc_date
local set_packed = utils.set_packed

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local delay = 3  -- in seconds
local new_timer = ngx.timer.at
local log = ngx.log
local ERR = ngx.ERR

local function set_apis(apis)
  local data = {
    ["apis"] = {},
    ["ids_by_host"] = {},
  }

  for _, api in ipairs(apis) do
    cache_computed_settings(api)

    local api_id = api["_id"]
    data["apis"][api_id] = api

    local host = api["frontend_host"]
    if not data["ids_by_host"][host] then
      data["ids_by_host"][host] = {}
    end
    table.insert(data["ids_by_host"][host], api_id)
  end

  set_packed(ngx.shared.apis, "packed_data", data)
end

local check
check = function(premature)
  if not premature then
    api_store.update_worker_cache_if_necessary()

    local ok, err = lock:unlock()
    if not ok then
      --log(ERR, "failed to unlock: ", err)
    end
    local elapsed, err = lock:lock("load_apis")

    if not err then
      local conn = mongol()
      conn:set_timeout(1000)

      local ok, err = conn:connect("127.0.0.1", 14001)
      if not ok then
        log(ERR, "connect failed: "..err)
      end

      local db = conn:new_db_handle("api_umbrella")
      local col = db:get_col("config_versions")

      local last_fetched_version = ngx.shared.apis:get("version") or 0
      local query = {
        ["$query"] = {
          version = {
            ["$gt"] = get_utc_date(last_fetched_version),
          },
        },
        ["$orderby"] = {
          version = -1
        },
      }
      local v = col:find_one(query)
      if v and v["config"] and v["config"]["apis"] then
        local apis = config["internal_apis"] or {}
        if v["config"]["apis"] then
          for _, api in ipairs(v["config"]["apis"]) do
            table.insert(apis, api)
          end
        end

        ngx.log(ngx.ERR, inspect(v["config"]["apis"]))
        set_apis(apis)
        ngx.shared.apis:set("version", v["version"])
      end

      conn:set_keepalive(10000, 5)
    end
    -- do the health check or other routine work
    local ok, err = new_timer(delay, check)
    if not ok then
      log(ERR, "failed to create timer: ", err)
      return
    end
  end
end

function _M.spawn()
  local apis = config["internal_apis"]
  set_apis(apis)
  ngx.shared.apis:set("version", 0)

  local ok, err = new_timer(0, check)
  if not ok then
    log(ERR, "failed to create timer: ", err)
    return
  end
end

return _M
