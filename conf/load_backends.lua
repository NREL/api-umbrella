local _M = {}

local api_store = require "api_store"
local dyups = require "ngx.dyups"
local inspect = require "inspect"
local lock = require "resty.lock"

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local delay = 0.05  -- in seconds
local new_timer = ngx.timer.at
local log = ngx.log
local ERR = ngx.ERR

local function setup_backends()
  for api_id, api in pairs(api_store.all_apis()) do
    local upstream = ""

    local balance = api["balance_algorithm"]
    if balance == "least_conn" or balance == "least_conn" then
      upstream = upstream .. balance .. ";\n"
    end

    local keepalive = api["keepalive_connections"] or 10
    upstream = upstream .. "keepalive " .. keepalive .. ";\n"

    if api["servers"] then
      for _, server in ipairs(api["servers"]) do
        upstream = upstream .. "server " .. server["host"] .. ":" .. server["port"] .. ";\n"
      end
    else
      upstream = upstream .. "server 127.255.255.255:80 down;\n"
    end

    local backend_id = "api_umbrella_" .. api["_id"] .. "_backend"
    local status, rv = dyups.update(backend_id, upstream);
  end
end

local function check(premature)
  if not premature then
    local ok, err = lock:unlock()
    if not ok then
      --log(ERR, "failed to unlock: ", err)
    end
    local elapsed, err = lock:lock("load_backends")

    if not err then
      local current_config_version = ngx.shared.apis:get("config_version") or 0
      local version = api_store.version() or 0
      local backends_version = ngx.shared.apis:get("current_backends_loaded_version") or 0

      if config_version == current_config_version and version > backends_version then
        setup_backends()
        ngx.shared.apis:set("current_backends_loaded_version", version)
      end
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
  local ok, err = new_timer(0, check)
  if not ok then
    log(ERR, "failed to create timer: ", err)
    return
  end
end

function _M.init()
  setup_backends()
end

return _M
