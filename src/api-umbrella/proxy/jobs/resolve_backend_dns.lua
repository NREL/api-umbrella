local _M = {}

local dns_cache = require "resty.dns.cache"
local interval_lock = require "api-umbrella.utils.interval_lock"
local load_backends = require "api-umbrella.proxy.load_backends"
local types = require "pl.types"
local utils = require "api-umbrella.proxy.utils"

local get_packed = utils.get_packed
local is_empty = types.is_empty

local delay = 1 -- in seconds

function _M.resolve(apis)
  local dns_changed = false
  for _, api in ipairs(apis) do
    if api["servers"] then
      for _, server in ipairs(api["servers"]) do
        if server["host"] and not server["_host_is_ip?"] and not server["_host_is_local_alias?"] then
          local dns, dns_err = dns_cache.new({
            dict = "dns_cache",
            minimise_ttl = true,
            negative_ttl = config["dns_resolver"]["negative_ttl"],
            max_stale = config["dns_resolver"]["max_stale"],
            resolver = {
              nameservers = config["dns_resolver"]["_nameservers"],
              timeout = config["dns_resolver"]["timeout"],
              retrans = config["dns_resolver"]["retries"],
            },
          })
          if dns_err then
            ngx.log(ngx.ERR, "failed to instantiate the resolver: ", dns_err)
          else
            local answers, query_err, stale = dns:query(server["host"])
            if query_err then
              ngx.log(ngx.ERR, "failed to query the DNS server: ", query_err)
            end

            if not answers and stale then
              answers = stale
            end

            local ips = {}
            if answers then
              for _, ans in ipairs(answers) do
                table.insert(ips, ans.address)
              end
            end

            table.sort(ips)
            local ips_string = nil
            if not is_empty(ips) then
              ips_string = table.concat(ips, ",")
            end

            local existing_ips_string = ngx.shared.resolved_hosts:get(server["host"])
            if ips_string ~= existing_ips_string then
              ngx.shared.resolved_hosts:set(server["host"], ips_string)
              dns_changed = true
            end
          end
        end
      end
    end
  end

  return dns_changed
end

local function do_check()
  local active_config = get_packed(ngx.shared.active_config, "packed_data") or {}
  local apis = active_config["apis"] or {}
  local dns_changed = _M.resolve(apis)
  if dns_changed then
    load_backends.setup_backends(apis)
  end
end

function _M.spawn()
  interval_lock.repeat_with_mutex('resolve_backend_dns', delay, do_check)
end

return _M
