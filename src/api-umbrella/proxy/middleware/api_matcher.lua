local matches_hostname = require "api-umbrella.utils.matches_hostname"
local stringx = require "pl.stringx"
local utils = require "api-umbrella.proxy.utils"

local append_array = utils.append_array
local set_uri = utils.set_uri
local startswith = stringx.startswith

local function apis_for_request_host(active_config)
  local apis = {}

  local all_apis = active_config["apis"] or {}
  local apis_for_default_host = {}
  for _, api in ipairs(all_apis) do
    if matches_hostname(api["_frontend_host_normalized"], api["_frontend_host_wildcard_regex"]) then
      table.insert(apis, api)
    elseif api["_frontend_host_normalized"] == config["_default_hostname_normalized"]then
      table.insert(apis_for_default_host, api)
    end
  end

  -- If a default host exists, append its APIs to the end sot hey have a lower
  -- matching precedence than any APIs that actually match the host.
  append_array(apis, apis_for_default_host)

  return apis
end

local function match_api(active_config, request_path)
  -- Find the API backends that match this host.
  local apis = apis_for_request_host(active_config)

  -- Search through each API backend for the first that matches the URL path
  -- prefix.
  for _, api in ipairs(apis) do
    if api["url_matches"] then
      for _, url_match in ipairs(api["url_matches"]) do
        local matches = false
        if not url_match["exact_match"] and startswith(request_path, url_match["frontend_prefix"]) then
          matches = true
        elseif url_match["exact_match"] and request_path == url_match["frontend_prefix"] then
          matches = true
        end

        if matches then
          return api, url_match
        end
      end
    end
  end
end

return function(active_config)
  local request_path = ngx.ctx.original_uri
  local api, url_match = match_api(active_config, request_path)

  if api and url_match then
    -- Rewrite the URL prefix path.
    local new_path, _, new_path_err = ngx.re.sub(request_path, url_match["_frontend_prefix_regex"], url_match["backend_prefix"], "jo")
    if new_path_err then
      ngx.log(ngx.ERR, "regex error: ", new_path_err)
    elseif new_path ~= request_path then
      set_uri(new_path)
    end

    local host = api["backend_host"] or ngx.ctx.host
    if api["_frontend_host_wildcard_regex"] then
      local matches, match_err = ngx.re.match(ngx.ctx.host_normalized, api["_frontend_host_wildcard_regex"], "jo")
      if matches then
        local wildcard_portion = matches[1]
        if wildcard_portion then
          local _, sub_err
          host, _, sub_err = ngx.re.sub(host, "^([*.])", wildcard_portion, "jo")
          if sub_err then
            ngx.log(ngx.ERR, "regex error: ", sub_err)
          end
        end
      elseif match_err then
        ngx.log(ngx.ERR, "regex error: ", match_err)
      end
    end

    ngx.var.proxy_host_header = host

    -- Set the nginx headers that will determine which nginx upstream this
    -- request gets proxied to.
    ngx.req.set_header("X-Api-Umbrella-Backend-Server-Scheme", api["backend_protocol"] or "http")

    -- Set the host on the request that we forward onto the caching server to
    -- the API backend ID. In combination with TrafficServer's
    -- proxy.config.url_remap.pristine_host_hdr option, this ensures that each
    -- API backend's cache remains separate (even if the URL paths are the
    -- same).
    --
    -- The real host that gets forwarded onto the backend is eventually
    -- replaced with the proper host stored in the X-Api-Umbrella-Backend-Host
    -- header. But we use the backend ID here for generating the cache key,
    -- rather than the real host so that separate backends on the same host but
    -- using different ports also remain in separate cache buckets.
    --
    -- TrafficServer 6.1+'s cachekey plugin might be a slightly more elegant
    -- way to base the cache key on the arbitrary X-Api-Umbrella-Backend-Id
    -- header once we upgrade to TrafficServer 6. However, since we're
    -- replacing the host afterwards anyway, using this fake temporary host to
    -- affect the cache key should be fine.
    for _, server in ipairs(api["servers"]) do
      ngx.req.set_header("X-Api-Umbrella-Backend-Server-Host", server["host"])
      ngx.req.set_header("X-Api-Umbrella-Backend-Server-Port", server["port"])
    end

    return api, url_match
  else
    return nil, nil, "not_found"
  end
end
