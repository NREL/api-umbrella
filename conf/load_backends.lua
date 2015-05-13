local _M = {}

local api_store = require "api_store"
local dyups = require "ngx.dyups"
local inspect = require "inspect"
local lock = require "resty.lock"
local plutils = require "pl.utils"
local resolver = require "resty.dns.resolver"
local types = require "pl.types"

local is_empty = types.is_empty
local split = plutils.split

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local delay = 1  -- in seconds
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


    local servers = {}
    if api["servers"] then
      for _, server in ipairs(api["servers"]) do
        -- ngx.log(ngx.ERR, "SERVER: " .. inspect(server));
        local ips = nil
        local m, err = ngx.re.match(server["host"], "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$")
        if m then
          ngx.log(ngx.ERR, "IS IP: " .. inspect(server["host"]))
          ips = server["host"]
        else
          ngx.log(ngx.ERR, "NOT IP: " .. inspect(server["host"]))
          ips = ngx.shared.resolved_hosts:get(server["host"])
        end

        if ips and server["port"] then
          ips = split(ips, ",", true)
          ngx.log(ngx.ERR, "IPS: " .. inspect(ips))
          for _, ip in ipairs(ips) do
            table.insert(servers, "server " .. ip .. ":" .. server["port"] .. ";")
          end
        end
      end
    end

    if is_empty(servers) then
      table.insert(servers, "server 127.255.255.255:80 down;")
    end

    upstream = upstream .. table.concat(servers, "\n") .. "\n"

    local backend_id = "api_umbrella_" .. api["_id"] .. "_backend"
    local status, rv = dyups.update(backend_id, upstream);
  end
end

local function do_check()
  local elapsed, err = lock:lock("load_backends")
  if err then
    return
  end

  local current_config_version = ngx.shared.apis:get("config_version") or 0
  local version = api_store.version() or 0
  local backends_version = ngx.shared.apis:get("current_backends_loaded_version") or 0

  if config_version == current_config_version and version > backends_version then
    setup_backends()
    ngx.shared.apis:set("current_backends_loaded_version", version)
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
    log(ERR, "failed to create timer: ", err)
    return
  end
end

function _M.init()
  setup_backends()
end

return _M
