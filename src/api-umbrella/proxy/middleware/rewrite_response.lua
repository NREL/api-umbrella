local host_strip_port = require "api-umbrella.utils.host_strip_port"
local inspect = require "inspect"
local stringx = require "pl.stringx"
local url = require "socket.url"
local utils = require "api-umbrella.proxy.utils"

local append_args = utils.append_args
local gsub = string.gsub
local startswith = stringx.startswith
local url_build = url.build
local url_parse = url.parse

local function set_cache_headers()
  local cache = "MISS"
  local via = ngx.var.sent_http_via
  if via then
    local match, err = ngx.re.match(via, "\\[(.+)\\]\\)")
    if match and match[1] then
      -- Parse the cache status out of the Via header into a simplified X-Cache
      -- HIT/MISS value:
      -- https://docs.trafficserver.apache.org/en/latest/admin/faqs.en.html?highlight=post#how-do-i-interpret-the-via-header-code
      --
      -- Note: The XDebug TrafficServer plugin could provide similar
      -- functionality, but currently has some odd edge cases:
      -- https://issues.apache.org/jira/browse/TS-3432
      local trafficserver_code = match[1]
      if string.sub(trafficserver_code, 2, 2) == "H" then
        cache = "HIT"
      end
    end
  end

  local existing_x_cache = ngx.var.sent_http_x_cache
  if not existing_x_cache or cache == "HIT" then
    ngx.header["X-Cache"] = cache
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
  if location then
    local parsed = url_parse(location)
    local matched_api = ngx.ctx.matched_api
    local host_matches = (matched_api and parsed["host"] == matched_api["_backend_host_without_port"])
    local relative = (not parsed["host"])
    local changed = false

    if host_matches then
      parsed["authority"] = matched_api["frontend_host"]
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
end

return function(settings)
  if settings then
    set_cache_headers()
    set_default_headers(settings)
    set_override_headers(settings)
    rewrite_redirects()
  end
end
