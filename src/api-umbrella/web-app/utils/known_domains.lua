local config = require("api-umbrella.utils.load_config")()
local get_active_config = require("api-umbrella.web-app.stores.active_config_store").get
local is_empty = require "api-umbrella.utils.is_empty"
local psl = require "api-umbrella.utils.psl"
local url_parse = require "api-umbrella.utils.url_parse"

local re_find = ngx.re.find
local re_match = ngx.re.match

local _M = {}

local function get_known_domains()
  local active_config = get_active_config()
  return active_config["known_domains"]
end

local function email_domain(email)
  local domain
  if email then
    local matches, match_err = re_match(email, [[@([^\s>]+)]], "jo")
    if matches and matches[1] then
      domain = matches[1]
    elseif match_err then
      ngx.log(ngx.ERR, "regex error: ", match_err)
    end
  end

  return domain
end

local function url_domain(url)
  local domain
  if url then
    local parsed, parse_err = url_parse(url)
    if not parsed or parse_err then
      ngx.log(ngx.ERR, "failed to parse: ", url, parse_err)
    else
      if parsed["scheme"] == "mailto" then
        domain = email_domain(parsed["path"])
      else
        domain = parsed["host"]
      end
    end
  end

  return domain
end

local function is_explicitly_allowed_url(url)
  local regex = config["web"]["allowed_signup_embed_urls_regex"]
  if not regex then
    return false
  end

  local find_from, _, find_err = re_find(url, regex, "ijo")
  if find_err then
    ngx.log(ngx.ERR, "regex error: ", find_err)
    return false
  end

  if find_from then
    return true
  else
    return false
  end
end

function _M.is_allowed_domain(domain)
  local private_suffix_domain
  if domain then
    private_suffix_domain = psl:registrable_domain(domain)
  end

  local known_domains = get_known_domains()
  if private_suffix_domain and known_domains and known_domains["private_suffixes"] and known_domains["private_suffixes"][private_suffix_domain] then
    return true
  else
    return false
  end
end

function _M.is_allowed_api_domain(domain)
  local known_domains = get_known_domains()
  if domain and known_domains and known_domains["apis"] and known_domains["apis"][domain] then
    return true
  else
    return false
  end
end

function _M.sanitized_url(url)
  if is_empty(url) then
    return nil
  end

  if is_explicitly_allowed_url(url) then
    return url
  end

  local domain = url_domain(url)
  if _M.is_allowed_domain(domain) then
    return url
  else
    ngx.log(ngx.WARN, "Rejecting unknown URL host: ", url)
    return nil
  end
end

function _M.sanitized_api_url(url)
  if is_empty(url) then
    return nil
  end

  if is_explicitly_allowed_url(url) then
    return url
  end

  local domain = url_domain(url)
  if _M.is_allowed_api_domain(domain) then
    return url
  else
    ngx.log(ngx.WARN, "Rejecting unknown API URL host: ", url)
    return nil
  end
end

function _M.sanitized_email(email)
  if is_empty(email) then
    return nil
  end

  if is_explicitly_allowed_url(email) then
    return email
  end

  local domain = email_domain(email)
  if _M.is_allowed_domain(domain) then
    return email
  else
    ngx.log(ngx.WARN, "Rejecting unknown email host: ", email)
    return nil
  end
end

return _M
