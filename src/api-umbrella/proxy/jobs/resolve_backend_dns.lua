local _M = {}

local api_store = require "api-umbrella.proxy.api_store"
local dyups = require "ngx.dyups"
local inspect = require "inspect"
local lock = require "resty.lock"
local resolver = require "resty.dns.resolver"
local types = require "pl.types"

local is_empty = types.is_empty

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local delay = 1  -- in seconds
local new_timer = ngx.timer.at
local log = ngx.log
local ERR = ngx.ERR

local function do_check()
  --ngx.log(ngx.ERR, "DO_CHECK")
  local elapsed, err = lock:lock("resolve_backend_dns")
  if err then
    return
  end

  local r, err = resolver:new({
    nameservers = { { "127.0.0.1", config["dnsmasq"]["port"] } },
    retrans = 3,
    timeout = 2000,
  })

  --ngx.log(ngx.ERR, "RESOLVER: " .. inspect(r))

  if not r then
    ngx.log(ngx.ERR, "failed to instantiate the resolver: ", err)

    local ok, err = lock:unlock()
    if not ok then
      ngx.log(ngx.ERR, "failed to unlock: ", err)
    end

    return
  end

  for _, api in ipairs(api_store.all_apis()) do
    if api["servers"] then
      for _, server in ipairs(api["servers"]) do
        if server["host"] then
          local answers, err = r:tcp_query(server["host"])
          if not answers then
            ngx.log(ngx.ERR, "failed to query the DNS server: ", err)
          else
            local ips = {}
            for i, ans in ipairs(answers) do
              table.insert(ips, ans.address)
            end

            if not is_empty(ips) then
              local ips_string = table.concat(ips, ",")
              ngx.shared.resolved_hosts:set(server["host"], ips_string)
            end
          end
        end
      end
    end
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

return _M
