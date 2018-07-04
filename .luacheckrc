std = "ngx_lua"

globals = {
  "WORKER_GROUP_ID",
}

max_line_length = false

files["src/api-umbrella/auto-ssl"] = {
  globals = {
    "auto_ssl",
  },
}

files["templates/etc/trafficserver"] = {
  std = "luajit",
  globals = {
    "TS_LUA_CACHE_LOOKUP_HIT_FRESH",
    "TS_LUA_CACHE_LOOKUP_HIT_STALE",
    "TS_LUA_REMAP_DID_REMAP",
    "do_global_read_request",
    "do_global_read_response",
    "do_global_send_request",
    "do_global_send_response",
    "do_remap",
    "ts",
  },
}
