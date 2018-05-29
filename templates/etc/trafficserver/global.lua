function do_global_read_request()
  -- If API Umbrella is injecting a static Authorization header into each
  -- request (to authenticate against the API backend), then we still want to
  -- allow caching of the responses, even though authorized responses aren't
  -- normally cached.
  --
  -- This works around this issue by temporarily storing the real Authorization
  -- header on a different header, so that Traffic Server will allow caching.
  -- We'll restore the original header in do_global_send_request() before
  -- sending the request to the API backend.
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
  -- Restore the original Authorization header that was potentially shifted to
  -- a different header to allow caching in do_global_read_request().
  local authorization = ts.server_request.header["X-Api-Umbrella-Orig-Authorization"]
  if authorization then
    ts.server_request.header["Authorization"] = authorization
    ts.server_request.header["X-Api-Umbrella-Orig-Authorization"] = nil
  end

  -- Remove temporary HTTP headers used to send information from nginx to
  -- Traffic Server, since these headers aren't actually needed by the
  -- underlying API backend.
  ts.server_request.header["X-Api-Umbrella-Backend-Server-Scheme"] = nil
  ts.server_request.header["X-Api-Umbrella-Backend-Server-Host"] = nil
  ts.server_request.header["X-Api-Umbrella-Backend-Server-Port"] = nil
  ts.server_request.header["X-Api-Umbrella-Allow-Authorization-Caching"] = nil

  return 0
end

function do_global_read_response()
  -- Support a private Surrogate-Control header (taking precedence over the
  -- normal Cache-Control header) to allow API backends to return this header
  -- to only control API Umbrella's caching layer, while having different
  -- Cache-Control settings for public caches.
  --
  -- We support this by shifting the Surrogate-Control header into place as the
  -- normal Cache-Control header, so Traffic Server will parse the surrogate
  -- header for all the normal TTL information. We'll then restore the original
  -- Cache-Control header in do_global_send_response().
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
  -- Restore the original Cache-Control header that was potentially shifted to
  -- a different header to allow Surrogate-Control support in
  -- do_global_read_response().
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
