local stringx = require "pl.stringx"
local url = require "socket.url"
local utils = require "api-umbrella.proxy.utils"

local append_args = utils.append_args
local gsub = string.gsub
local startswith = stringx.startswith
local url_build = url.build
local url_parse = url.parse

local function set_cache_header()
  local cache = "MISS"
  local via = ngx.header["Via"]
  if via then
    local matches, match_err = ngx.re.match(via, "ApacheTrafficServer \\[([^\\]]+)\\]", "jo")
    if matches and matches[1] then
      -- Parse the cache status out of the Via header into a simplified X-Cache
      -- HIT/MISS value:
      -- https://docs.trafficserver.apache.org/en/latest/admin/faqs.en.html?highlight=post#how-do-i-interpret-the-via-header-code
      --
      -- Note: The XDebug TrafficServer plugin could provide similar
      -- functionality, but currently has some odd edge cases:
      -- https://issues.apache.org/jira/browse/TS-3432
      local trafficserver_code = matches[1]
      local cache_lookup_code = string.sub(trafficserver_code, 2, 2)
      if cache_lookup_code == "H" or cache_lookup_code == "R" then
        cache = "HIT"
      end
    elseif match_err then
      ngx.log(ngx.ERR, "regex error: ", match_err)
    end
  end

  local existing_x_cache = ngx.header["X-Cache"]
  if not existing_x_cache or cache == "HIT" then
    ngx.header["X-Cache"] = cache
  end
end

local function set_via_header()
  local via = ngx.header["Via"]
  if via then
    -- Replace the server hostname or hex-encoded IP address in the Via header
    -- TrafficServer appends with an alias of "api-umbrella". We have to return
    -- some name here to be compliant with the Via header specification, but we
    -- don't want to expose internal machine names or IPs.
    local new_via, _, err = ngx.re.sub(via, "(http/[0-9\\.]+) [^ ]+ (\\(ApacheTrafficServer[^\\)]*\\))$", "$1 api-umbrella $2", "jo")
    if new_via then
      ngx.header["Via"] = new_via
    elseif err then
      ngx.log(ngx.ERR, "regex error: ", err)
    end
  end
end

local function set_default_headers(settings)
  if settings["_default_response_headers"] then
    local existing_headers = ngx.resp.get_headers()
    for _, header in ipairs(settings["_default_response_headers"]) do
      if not existing_headers[header["key"]] then
        ngx.header[header["key"]] = header["value"]
      end
    end
  end
end

local function set_override_headers(settings)
  if settings["_override_response_headers"] then
    for _, header in ipairs(settings["_override_response_headers"]) do
      ngx.header[header["key"]] = header["value"]
    end
  end
end

local function rewrite_redirects()
  local location = ngx.header["Location"]
  if type(location) ~= "string" or location == "" then
    return
  end

  if ngx.ctx.skip_location_rewrites then
    return
  end

  local parsed, parse_err = url_parse(location)
  if not parsed or parse_err then
    ngx.log(ngx.ERR, "error parsing Location header: ", location, " error: ", parse_err)
    return
  end

  local matched_api = ngx.ctx.matched_api
  local host_matches = (matched_api and parsed["host"] == matched_api["_backend_host_normalized"])
  local relative = (not parsed["host"])
  local changed = false

  if host_matches then
    -- For wildcard hosts, keep the same host as on the incoming request. For
    -- all others, use the frontend host declared on the API.
    if matched_api["frontend_host"] == "*" then
      parsed["authority"] = ngx.ctx.host
    else
      parsed["authority"] = matched_api["frontend_host"]
    end

    parsed["host"] = nil
    changed = true
  end

  if host_matches or relative then
    if matched_api and matched_api["url_matches"] then
      for _, url_match in ipairs(matched_api["url_matches"]) do
        if startswith(parsed["path"], url_match["backend_prefix"]) then
          parsed["path"] = gsub(parsed["path"], url_match["_backend_prefix_matcher"], url_match["frontend_prefix"], 1)
          changed = true
          break
        end
      end
    end
  end

  if changed and ngx.ctx.api_key then
    parsed["query"] = append_args(parsed["query"], "api_key=" .. ngx.ctx.api_key)
    changed = true
  end

  if changed then
    ngx.header["Location"] = url_build(parsed)
  end
end

return function(settings)
  set_cache_header()
  set_via_header()

  if settings then
    set_default_headers(settings)
    set_override_headers(settings)
  end

  if config["app_env"] == "test" then
    if ngx.var.http_x_api_umbrella_test_debug_workers == "true" then
      ngx.header["X-Api-Umbrella-Test-Worker-Id"] = ngx.worker.id()
      ngx.header["X-Api-Umbrella-Test-Worker-Count"] = ngx.worker.count()
      ngx.header["X-Api-Umbrella-Test-Worker-Pid"] = ngx.worker.pid()
    end

    if ngx.var.http_x_api_umbrella_test_return_request_id == "true" then
      ngx.header["X-Api-Umbrella-Test-Request-Id"] = ngx.var.x_api_umbrella_request_id
    end
  end

  rewrite_redirects()
end
