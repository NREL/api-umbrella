function do_remap()
  ts.client_request.set_url_host(ts.client_request.header["X-Api-Umbrella-Backend-Server-Host"])
  ts.client_request.set_url_port(ts.client_request.header["X-Api-Umbrella-Backend-Server-Port"])
  ts.client_request.set_url_scheme(ts.client_request.header["X-Api-Umbrella-Backend-Server-Scheme"])
  return TS_LUA_REMAP_DID_REMAP
end
