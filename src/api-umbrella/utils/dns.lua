local config = require "api-umbrella.proxy.models.file_config"
local dns_resolver = require "resty.dns.resolver"
local mlcache = require "resty.mlcache"

local table_concat = table.concat

local _M = {
  resolver = dns_resolver,
}

local cache, mlcache_err = mlcache.new("dns", "dns_cache")
if mlcache_err then
  ngx.log(ngx.ERR, "mlcache error: ", mlcache_err)
end

local function cache_key(name, options)
  if not options then
    return name
  end

  return table_concat({
    name,
    options["qtype"],
    options["authority_section"],
    options["additional_section"],
  }, "-")
end

local function perform_query(name, options)
  local resolver, resolver_err = dns_resolver:new({
    nameservers = config["dns_resolver"]["_nameservers_resty"],
    timeout = config["dns_resolver"]["timeout"],
    retrans = config["dns_resolver"]["retries"],
  })
  if not resolver then
    ngx.log(ngx.ERR, "resolver error: ", resolver_err)
    return nil, resolver_err
  end

  local answers, query_err = resolver:query(name, options)
  if not answers then
    ngx.log(ngx.ERR, "DNS query error: ", query_err)
    return nil, query_err
  end
  if answers.errcode then
    ngx.log(ngx.ERR, "DNS query error: ", answers.errstr)
    return nil, query_err
  end

  -- Cache these results based on the minimum TTL in the answers.
  local ttl = 60
  for _, answer in ipairs(answers) do
    if answer["ttl"] < ttl then
      ttl = answer["ttl"]
    end
  end

  ngx.log(ngx.ERR, "ANSWERS: ", answers)
  ngx.log(ngx.ERR, "TTL: ", ttl)
  return answers, nil, ttl
end

_M.query = function(name, options)
  local key = cache_key(name, options)
  return cache:get(key, nil, perform_query, name, options)
end

return _M
