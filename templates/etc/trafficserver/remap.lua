function do_remap()
  ts.client_request.set_url_host(ts.client_request.header["X-Api-Umbrella-Backend-Server-Host"])
  ts.client_request.set_url_port(ts.client_request.header["X-Api-Umbrella-Backend-Server-Port"])
  ts.client_request.set_url_scheme(ts.client_request.header["X-Api-Umbrella-Backend-Server-Scheme"])

  -- For cache key purposes, allow HEAD requests to re-use the cache key for
  -- GET requests (since HEAD queries can be answered from cached GET data).
  -- But since HEAD requests by themselves aren't cacheable, we don't have to
  -- worry about GET requests re-using the HEAD response.
  local method_key = ts.client_request.get_method()
  if method_key == "HEAD" then
    method_key = "GET"
  end

  local cache_key = {
    -- Note that by default, the cache key doesn't include the backend server
    -- port, so by re-setting the cache key based on the full URL here, this
    -- also helps ensure the backend port is included (so backends running on
    -- separate ports are kept separate).
    ts.client_request.get_url(),

    -- Include the HTTP method (GET, POST, etc) in the cache key. This prevents
    -- delayed processing when long-running GET and POSTs are running against
    -- the same URL:  https://issues.apache.org/jira/browse/TS-3431
    method_key,

    -- Include the Host header in the cache key, since this may differ from the
    -- underlying server host/IP being connected to (for virtual hosts). The
    -- underlying server host is included in get_url() below, but we need both
    -- to be part of the cache key to keep underling servers and virtual hosts
    -- cached separately.
    ts.client_request.header["Host"],
  }
  ts.http.set_cache_lookup_url(table.concat(cache_key, "/"))

  return TS_LUA_REMAP_DID_REMAP
end
