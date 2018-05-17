function cache_lookup()
  local cache_status = ts.http.get_cache_lookup_status()
  ts.error("REMAP CACHE_LOOKUP CACHE STATUS: " .. tostring(cache_status))

  -- ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_OPEN_READ_RETRY_TIME, 10)
  -- ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_MAX_OPEN_READ_RETRIES, 10)
end

function do_remap()
  ts.client_request.set_url_host(ts.client_request.header["X-Api-Umbrella-Backend-Server-Host"])
  ts.client_request.set_url_port(ts.client_request.header["X-Api-Umbrella-Backend-Server-Port"])
  ts.client_request.set_url_scheme(ts.client_request.header["X-Api-Umbrella-Backend-Server-Scheme"])

  ts.hook(TS_LUA_HOOK_CACHE_LOOKUP_COMPLETE, cache_lookup)

  local cache_status = ts.http.get_cache_lookup_status()
  ts.error("REMAP CACHE STATUS: " .. tostring(cache_status))
  -- ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_OPEN_READ_RETRY_TIME, 10)
  -- ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_MAX_OPEN_READ_RETRIES, 10)
  return TS_LUA_REMAP_DID_REMAP
end
