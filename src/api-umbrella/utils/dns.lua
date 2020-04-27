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
  ngx.log(ngx.ERR, "PERFORM_QUERY")
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

  local ttl = 60

  -- If we got an answer back, but it was an error (eg, NXDOMAIN),
  if answers.errcode then
    ngx.log(ngx.ERR, "DNS returned error code: ", answers.errcode, ": ", answers.errstr)
    return nil, nil, ttl
  end

  -- Cache these results based on the minimum TTL in the answers.
  for _, answer in ipairs(answers) do
    if answer["ttl"] < ttl then
      ttl = answer["ttl"]
    end
  end

  local inspect = require "inspect"
  ngx.log(ngx.ERR, "ANSWERS: ", inspect(answers))
  ngx.log(ngx.ERR, "TTL: ", ttl)
  return answers, nil, ttl
end

_M.query = function(name, options)
  local key = cache_key(name, options)
  local value, err, hit_level = cache:get(key, nil, perform_query, name, options)
  local inspect = require "inspect"
  ngx.log(ngx.ERR, "QUERY VALUE: ", inspect(value))
  ngx.log(ngx.ERR, "QUERY ERR: ", err)
  ngx.log(ngx.ERR, "QUERY HIT_LEVEL: ", hit_level)
  return value, err, hit_level
end

return _M
