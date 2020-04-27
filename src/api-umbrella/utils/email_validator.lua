local config = require "api-umbrella.proxy.models.file_config"
local dns = require "api-umbrella.utils.dns"
local split = require("ngx.re").split

    local inspect = require "inspect"

local dns_query = dns.query
local dns_type_mx = dns.resolver.TYPE_MX
local match = ngx.re.match
local table_insert = table.insert
local table_concat = table.concat

local _M = {}

local function domain_allowed(domain, options)
  ngx.log(ngx.ERR, "DOMAIN ALLOWED")
  assert(domain)
  assert(options)

  ngx.log(ngx.ERR, "DOMAIN ALLOWED2")
  local all_domains = _M.domain_parts(domain)
  ngx.log(ngx.ERR, "DOMAIN ALLOWED domains: ", inspect(all_domains))

  -- Check to see if this domain (or root domain) has been explicitly
  -- allowed.
  if config["web"]["email"]["_allowed_domains"] then
    for _, possible_domain in ipairs(all_domains) do
      if config["web"]["email"]["_allowed_domains"][possible_domain] then
        return true
      end
    end
  end

  -- Check to see if this domain (or root domain) has been explicitly
  -- blocked.
  if options["exclude_blocked"] and config["web"]["email"]["_blocked_domains"] then
    for _, possible_domain in ipairs(all_domains) do
      if config["web"]["email"]["_blocked_domains"][possible_domain] then
        return false
      end
    end
  end

  -- Check to see if this domain (or root domain) is for a disposable e-mail
  -- service.
  if options["exclude_disposable"] then
    for _, possible_domain in ipairs(all_domains) do
      if config["web"]["email"]["disposable_domains"][possible_domain] then
        return false
      end
    end
  end

  -- If the domain hasn't been explicitly allowed or blocked, return nil to
  -- indicate further processing might be needed by other checks (eg MX
  -- checks).
  return nil
end

function _M.extract_domain(email)
  local domain_matches, err = match(email, "@(.+)$", "jo")
  if err then
    return nil, "regex error: " .. err
  elseif not domain_matches or not domain_matches[1] then
    return nil, "no domain found in e-mail address"
  end
  ngx.log(ngx.ERR, "EXTRACT DOMAIN: ", inspect(domain_matches))

  return domain_matches[1]
end

-- Come up with a list of all the possible subdomains and root domains for
-- the e-mail domain for testing against allow/block lists. For example,
-- for "mail.example.com", test "mail.example.com", "example.com" and
-- "com".
function _M.domain_parts(domain)
  local all_domains = {}
  local domain_parts = split(domain, "\\.", "jo")
  local domain_parts_length = #domain_parts
  for i, _ in ipairs(domain_parts) do
    table_insert(all_domains, table_concat({ unpack(domain_parts, i, domain_parts_length) }, "."))
  end

  return all_domains
end

function _M.is_valid_domain(domain, options)
  ngx.log(ngx.ERR, "IS VALID DOMAIN: " .. inspect(domain))
  ngx.log(ngx.ERR, "IS VALID DOMAIN: " .. inspect(options))
  assert(options)

  -- First, see if the domain is explicitly allowed, blocked, or disposable.
  ngx.log(ngx.ERR, "BLAH")
  local allowed = domain_allowed(domain, options)
  ngx.log(ngx.ERR, "DOMAIN ALLOWED: ", inspect(allowed))
  if allowed ~= nil then
    return allowed
  end

  -- Next, check to see if this domain has valid MX records for receiving
  -- e-mail.
  if options["validate_mx"] then
    local answers, err = dns_query(domain, { qtype = dns_type_mx })
    ngx.log(ngx.ERR, "MX VALIDATE: ", inspect(answers))
    ngx.log(ngx.ERR, "MX VALIDATE: ", inspect(err))
    if err then
      return false
    end

    -- Validate the result of the MX record to see if the underlying domain
    -- is allowed, blocked, or disposable.
    for _, mx_domain in ipairs(answers) do
      local mx_allowed = domain_allowed(mx_domain, options)
      ngx.log(ngx.ERR, "MX ALLOWED: ", inspect(mx_allowed))
      if mx_allowed ~= nil then
        return mx_allowed
      end
    end
  end

  -- If the domain hasn't been explicitly allowed or blocked by now, then it
  -- should be considered valid.
  return true
end

function _M.is_valid_email(email, options)
  ngx.log(ngx.ERR, "IS VALID EMAIL: ", inspect(email))
  ngx.log(ngx.ERR, "IS VALID EMAIL OPTIONS: ", inspect(options))

  assert(options)

  if not email then
    return false
  end

  -- Validate the email based on regex.
  if options["regex"] then
    local matches, err = match(email, options["regex"], "ijo")
    ngx.log(ngx.ERR, "MATCHES: ", inspect(matches))
    ngx.log(ngx.ERR, "MATCHES ERR: ", inspect(err))
    if err then
      ngx.log(ngx.ERR, "regex error: ", err)
      return false
    end
    if matches == nil then
      return false
    end
  end

  -- Extract the domain portion of the email and validate based on the domain.
  local domain, domain_err = _M.extract_domain(email)
  if not domain then
    ngx.log(ngx.ERR, domain_err)
    return false
  end
  ngx.log(ngx.ERR, "FOOOOO")
  return _M.is_valid_domain(domain, options)
end

return _M
