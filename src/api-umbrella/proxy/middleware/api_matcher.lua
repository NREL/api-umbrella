local matches_hostname = require "api-umbrella.utils.matches_hostname"
local stringx = require "pl.stringx"
local utils = require "api-umbrella.proxy.utils"

local append_array = utils.append_array
local gsub = string.gsub
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
        if startswith(request_path, url_match["frontend_prefix"]) then
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
    local new_path = gsub(request_path, url_match["_frontend_prefix_matcher"], url_match["backend_prefix"], 1)
    if new_path ~= request_path then
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

    -- Set the nginx headers that will determine which nginx upstream this
    -- request gets proxied to.
    ngx.req.set_header("X-Api-Umbrella-Backend-Scheme", api["backend_protocol"] or "http")
    ngx.req.set_header("X-Api-Umbrella-Backend-Host", host)
    ngx.req.set_header("X-Api-Umbrella-Backend-Id", api["_id"])

    return api
  else
    return nil, "not_found"
  end
end
