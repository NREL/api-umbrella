local append_args = require("api-umbrella.proxy.utils").append_args
local config = require "api-umbrella.proxy.models.file_config"
local startswith = require("pl.stringx").startswith
local url_build = require "api-umbrella.utils.url_build"
local url_parse = require("url").parse

-- Parse the "cache-lookup" status out of the Via header into a simplified
-- X-Cache HIT/MISS value:
-- https://docs.trafficserver.apache.org/en/7.1.x/appendices/faq.en.html?highlight=asked#how-do-i-interpret-the-via-header-code
--
-- Note: Ideally we could handle this at the TrafficServer lua layer with the
-- simpler ts.http.get_cache_lookup_status(). However, that lookup status isn't
-- always accurate, since certain scenarios trigger cache revalidation without
-- updating the status code (like cache items not used due to authorization
-- headers, or this similar issue using the same underling
-- TSHttpTxnCacheLookupStatusGet:
-- https://issues.apache.org/jira/browse/TS-3432). So instead, we'll continue
-- to handle it here, using nginx's lua layer, instead of TrafficServer's lua
-- layer, since nginx's compiled regexes are probably a bit better optimized.
local function set_cache_header()
  local cache = "MISS"
  local via = ngx.header["Via"]
  if via then
    local matches, match_err = ngx.re.match(via, "ApacheTrafficServer \\[.(.)", "jo")
    if matches and matches[1] then
      local cache_lookup_code = matches[1]
      if cache_lookup_code == "H" or cache_lookup_code == "R" then
        cache = "HIT"
      end
    elseif match_err then
      ngx.log(ngx.ERR, "regex error: ", match_err)
    end
  end

  -- If the underlying API backend returned it's own X-Cache header, allow that
  -- to take precedent, unless we have a cache hit at our layer.
  local existing_x_cache = ngx.header["X-Cache"]
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
  if type(location) ~= "string" or location == "" then
    return
  end

  -- If the redirect was forced within the gatekeeper layer by an error handler
  -- (and the redirect didn't actually come from the API backend), then no
  -- further rewriting is necessary.
  if ngx.ctx.gatekeeper_denied_code then
    return
  end

  local parsed, _, parse_err = url_parse(location)
  if not parsed or parse_err then
    ngx.log(ngx.ERR, "error parsing Location header: ", location, " error: ", parse_err)
    return
  end

  local matched_api = ngx.ctx.matched_api
  local parsed_hostname = parsed["hostname"]
  local relative = (not parsed_hostname)
  local changed = false
  local host_matches = false
  if not relative then
    if matched_api and parsed_hostname == matched_api["_backend_host_normalized"] then
      host_matches = true
    elseif parsed_hostname == ngx.ctx.proxy_server_host or parsed_hostname == ngx.ctx.host_normalized then
      host_matches = true
    end
  end

  if host_matches then
    -- For wildcard hosts, keep the same host as on the incoming request. For
    -- all others, use the frontend host declared on the API.
    local host
    if not matched_api or matched_api["frontend_host"] == "*" then
      host = ngx.ctx.host_normalized
    else
      host = matched_api["_frontend_host_normalized"]
    end

    local scheme = parsed["scheme"]
    if scheme == "http" and config["override_public_http_proto"] then
      scheme = config["override_public_http_proto"]
    elseif scheme == "https" and config["override_public_https_proto"] then
      scheme = config["override_public_https_proto"]
    end

    local port
    if scheme == "https" then
      port = config["override_public_https_port"] or config["https_port"]
      if port == 443 then
        port = nil
      end
    elseif scheme == "http" then
      port = config["override_public_http_port"] or config["http_port"]
      if port == 80 then
        port = nil
      end
    end

    parsed["scheme"] = scheme
    parsed["hostname"] = host
    parsed["port"] = port
    parsed["host"] = nil
    changed = true
  end

  -- If the redirect being returned possibly contains paths for the underlying
  -- backend URL, then rewrite the path.
  if (host_matches or relative) and matched_api then
    -- If the redirect path begins with the backend prefix, then consider it
    -- for rewriting.
    local parsed_path = parsed["path"]
    local url_match = ngx.ctx.matched_api_url_match
    if url_match and startswith(parsed_path, url_match["backend_prefix"]) then
      -- As long as the patah matches the backend prefix, mark as changed, so
      -- the api key is appended (regardless of whether we actually replaced
      -- the path).
      changed = true

      -- Don't rewrite the path if the frontend prefix contains the backend
      -- prefix and the redirect path already contains the frontend prefix.
      --
      -- This helps ensure that if the API backend is already returning
      -- public/frontend URLs, we don't try to rewrite these again. -
      local rewrite_path = true
      if url_match["_frontend_prefix_contains_backend_prefix"] and startswith(parsed_path, url_match["frontend_prefix"]) then
        rewrite_path = false
      end

      if rewrite_path then
        parsed["path"] = ngx.re.sub(parsed_path, url_match["_backend_prefix_regex"], url_match["frontend_prefix"], "jo")
      end
    end
  end

  if changed and ngx.ctx.api_key then
    parsed["query"] = append_args(parsed["query"], "api_key=" .. ngx.ctx.api_key, true)
    changed = true
  end

  if changed then
    ngx.header["Location"] = url_build(parsed)
  end
end

return function(settings)
  set_cache_header()

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
