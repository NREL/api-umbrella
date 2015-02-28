local api_store = require "api_store"
local inspect = require "inspect"
local stringx = require "pl.stringx"
local types = require "pl.types"
local utils = require "utils"

local apis_for_host = api_store.for_host
local append_array = utils.append_array
local gsub = string.gsub
local is_empty = types.is_empty
local startswith = stringx.startswith

local function apis_for_request_host()
  -- Find APIs matching the exact host.
  local host = ngx.ctx.host
  local apis = apis_for_host(host) or {}

  -- Append APIs matching the host with or without the port.
  local host_without_port = string.match(host, "(.+):")
  if host_without_port then
    local apis_without_port = apis_for_host(host_without_port)
    if apis_without_port then
      append_array(apis, apis_without_port)
    end
  else
    local protocol = ngx.ctx.protocol
    local port = (protocol == "https") and "443" or "80"
    local host_with_default_port = host .. ":" .. port
    local apis_with_port = apis_for_host(host_with_default_port)
    if apis_with_port then
      append_array(apis, apis_with_port)
    end
  end

  -- If no APIs have been found, use the optional "default_frontend_host"
  -- configuration to lookup the host.
  local default_host = config["gatekeeper"]["default_frontend_host"]
  if is_empty(apis) and default_host then
    local default_apis = apis_for_host(default_host)
    if default_apis then
      apis = default_apis
    end
  end

  -- Finally, append wildcard hosts.
  local wildcard_apis = apis_for_host("*")
  if wildcard_apis then
    append_array(apis, wildcard_apis)
  end

  return apis
end

local function match_api(request_path)
  -- Find the API backends that match this host.
  local apis = apis_for_request_host()

  -- Search through each API backend for the first that matches the URL path
  -- prefix.
  for _, api in ipairs(apis) do
    if api["url_matches"] then
      for _, url_match in ipairs(api["url_matches"]) do
        if startswith(request_path, url_match.frontend_prefix) then
          return api, url_match
        end
      end
    end
  end
end

return function(user)
  local request_path = ngx.ctx.uri
  local api, url_match = match_api(request_path)

  if api and url_match then
    -- Rewrite the URL prefix path.
    new_path = gsub(request_path, url_match["_frontend_prefix_matcher"], url_match["backend_prefix"], 1)
    if new_path ~= request_path then
      ngx.req.set_uri(new_path)
    end

    -- Set the nginx variables that will determine which nginx upstream this
    -- request gets proxied to.
    ngx.var.api_umbrella_backend_scheme = api["backend_protocol"] or "http"
    ngx.var.api_umbrella_backend_host = api["backend_host"] or ngx.ctx.host
    ngx.var.api_umbrella_backend_id = api["_id"]

    ngx.req.set_header("X-Api-Umbrella-Backend-Scheme", ngx.var.api_umbrella_backend_scheme)
    ngx.req.set_header("X-Api-Umbrella-Backend-Host", ngx.var.api_umbrella_backend_host)
    ngx.req.set_header("X-Api-Umbrella-Backend-Id", ngx.var.api_umbrella_backend_id)

    return api, url_match
  else
    return nil, nil, "not_found"
  end
end
