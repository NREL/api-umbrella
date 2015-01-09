local api_store = require "api_store"
local moses = require "moses"
local inspect = require "inspect"
local utils = require "utils"
local stringx = require "pl.stringx"

local apis_for_request_host = function()
  -- Find APIs matching the exact host.
  local host = ngx.var.http_x_forwarded_host or ngx.var.host
  local apis = api_store.for_host(host) or {}

  -- Append APIs matching the host with or without the port.
  local port_matches = string.match(host, "(.+):")
  if port_matches then
    local host_without_port = port_matches[1]
    local apis_without_port = api_store.for_host(host_without_port)
    if apis_without_port then
      apis = moses.append(apis, apis_without_port)
    end
  else
    local protocol = ngx.var.http_x_forwarded_proto or ngx.var.scheme
    local port = (protocol == "https") and "443" or "80"
    local host_with_default_port = host .. ":" .. port
    local apis_with_port = api_store.for_host(host_with_default_port)
    if apis_with_port then
      apis = moses.append(apis, apis_with_port)
    end
  end

  -- If no APIs have been found, use the optional "default_frontend_host"
  -- configuration to lookup the host.
  local default_host = config["gatekeeper"]["default_frontend_host"]
  if moses.isEmpty(apis) and default_host then
    local default_apis = api_store.for_host(default_host)
    if default_apis then
      apis = default_apis
    end
  end

  -- Finally, append wildcard hosts.
  local wildcard_apis = api_store.for_host("*")
  if wildcard_apis then
    apis = moses.append(apis, wildcard_apis)
  end

  return apis
end

local match_api = function(request_path)
  local apis = apis_for_request_host()

  for _, api in ipairs(apis) do
    if api["url_matches"] then
      for _, url_match in ipairs(api["url_matches"]) do
        if stringx.startswith(request_path, url_match.frontend_prefix) then
          return api, url_match
        end
      end
    end
  end
end

return function(user)
  local request_path = ngx.var.uri
  local api, url_match = match_api(request_path)

  if api and url_match then
    -- Rewrite the URL prefix path.
    new_path = string.gsub(request_path, url_match["frontend_prefix_matcher"], url_match["backend_prefix"], 1)
    if new_path ~= request_path then
      ngx.req.set_uri(new_path)
    end

    -- Set the nginx variables that will determine which nginx upstream this
    -- request gets proxied to.
    ngx.var.api_umbrella_backend_scheme = api["backend_protocol"] or "http"
    ngx.var.api_umbrella_backend_host = api["backend_host"]
    ngx.var.api_umbrella_backend_id = api["_id"]

    return api, url_match
  else
    return nil, nil, "not_found"
  end
end
