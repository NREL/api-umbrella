function do_remap()
  ts.client_request.set_url_host(ts.client_request.header["X-Api-Umbrella-Backend-Server-Host"])
  ts.client_request.set_url_port(ts.client_request.header["X-Api-Umbrella-Backend-Server-Port"])
  ts.client_request.set_url_scheme(ts.client_request.header["X-Api-Umbrella-Backend-Server-Scheme"])

  local cache_key = {
    -- Include the HTTP method (GET, POST, etc) in the cache key. This prevents
    -- delayed processing when long-running GET and POSTs are running against
    -- the same URL:  https://issues.apache.org/jira/browse/TS-3431
    ts.client_request.get_method(),

    -- Note that by default, the cache key doesn't include the backend host
    -- port, so by re-setting the cache key based on the full URL here, this
    -- also helps ensure the backend port is included (so backends running on
    -- separate ports are kept separate).
    ts.client_request.get_url(),
  }
  ts.http.set_cache_lookup_url(table.concat(cache_key, "/"))

  return TS_LUA_REMAP_DID_REMAP
end
