local inspect = require "inspect"

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

return function(settings)
  if settings then
    set_cache_headers()
    set_default_headers(settings)
    set_override_headers(settings)
  end
end
