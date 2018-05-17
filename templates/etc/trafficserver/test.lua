function do_global_read_request()
  local allow_authorization_caching = ts.client_request.header["X-Api-Umbrella-Allow-Authorization-Caching"]
  if allow_authorization_caching == "true" then
    local authorization = ts.client_request.header["Authorization"]
    if authorization then
      ts.client_request.header["X-Api-Umbrella-Orig-Authorization"] = authorization
      ts.client_request.header["Authorization"] = nil
    end
  end

  return 0
end

function do_global_send_request()
  local authorization = ts.server_request.header["X-Api-Umbrella-Orig-Authorization"]
  if authorization then
    ts.server_request.header["Authorization"] = authorization
    ts.server_request.header["X-Api-Umbrella-Orig-Authorization"] = nil
  end

  return 0
end

function do_global_read_response()
  local surrogate_control = ts.server_response.header["Surrogate-Control"]
  if surrogate_control then
    local cache_control = ts.server_response.header["Cache-Control"]
    if cache_control then
      ts.server_response.header["X-Api-Umbrella-Orig-Cache-Control"] = cache_control
    end

    ts.server_response.header["Cache-Control"] = surrogate_control
  end

  return 0
end

function do_global_send_response()
  local surrogate_control = ts.client_response.header["Surrogate-Control"]
  if surrogate_control then
    ts.client_response.header["Cache-Control"] = nil
    ts.client_response.header["Surrogate-Control"] = nil
    local cache_control = ts.client_response.header["X-Api-Umbrella-Orig-Cache-Control"]
    if cache_control then
      ts.client_response.header["Cache-Control"] = cache_control
      ts.client_response.header["X-Api-Umbrella-Orig-Cache-Control"] = nil
    end
  end

  return 0
end

function do_global_cache_lookup_complete()
  local cache = ts.http.get_cache_lookup_url()
  ts.error("CACHE URL: " .. tostring(cache))

  local cache_status = ts.http.get_cache_lookup_status()
  ts.error("CACHE STATUS: " .. tostring(cache_status))

  ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_OPEN_READ_RETRY_TIME, 10)
  ts.http.config_int_set(TS_LUA_CONFIG_HTTP_CACHE_MAX_OPEN_READ_RETRIES, 10)
end
