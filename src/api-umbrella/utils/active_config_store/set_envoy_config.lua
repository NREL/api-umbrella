local file_config = require("api-umbrella.utils.load_config")()
local http = require "resty.http"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local path_join = require "api-umbrella.utils.path_join"
local writefile = require("pl.utils").writefile

local re_find = ngx.re.find
local sleep = ngx.sleep

local function build_cluster_resource(cluster_name, options)
  local resource = {
    ["@type"] = "type.googleapis.com/envoy.config.cluster.v3.Cluster",
    name = cluster_name,
    type = "STRICT_DNS",
    wait_for_warm_on_init = false,
    typed_dns_resolver_config = {
      name = "envoy.network.dns_resolver.cares",
      typed_config = {
        ["@type"] = "type.googleapis.com/envoy.extensions.network.dns_resolver.cares.v3.CaresDnsResolverConfig",
        resolvers = file_config["dns_resolver"]["_nameservers_envoy"],
      },
    },
    dns_lookup_family = "V4_PREFERRED",
    respect_dns_ttl = true,
    ignore_health_on_host_removal = true,
    load_assignment = {
      cluster_name = cluster_name,
      endpoints = {
        lb_endpoints = {},
      },
    },
    connect_timeout = file_config["envoy"]["_connect_timeout"],
    upstream_connection_options = {
      tcp_keepalive = {
        keepalive_probes = 2,
        keepalive_time = 15,
        keepalive_interval = 5,
      },
    },
  }

  if not file_config["dns_resolver"]["allow_ipv6"] then
    resource["dns_lookup_family"] = "V4_ONLY"
  end

  -- Use the "negative_ttl" time as Envoy's DNS refresh rate. Since we have
  -- "respect_dns_ttl" enabled, successful DNS requests will use that refresh
  -- rate instead of this one. So effectively the "dns_refresh_rate" should
  -- only be used in failure situations, so we can use this to provide a TTL
  -- for negative responses.
  --
  -- Envoy also supports the more explicit "dns_failure_refresh_rate" option,
  -- but that includes an exponential backoff algorithm, with random jitter,
  -- making it harder to test against. So to replicate how our "negative_ttl"
  -- has worked under other DNS situations, we will use this "dns_refresh_rate"
  -- (which doesn't do backoff or jitter).
  if file_config["dns_resolver"]["negative_ttl"] then
    resource["dns_refresh_rate"] = file_config["dns_resolver"]["negative_ttl"] .. "s"
  end

  local servers
  local tls_sni

  if options["api_backend"] then
    if options["api_backend"]["balance_algorithm"] == "least_conn" then
      resource["lb_policy"] = "LEAST_REQUEST"
    elseif options["api_backend"]["balance_algorithm"] == "round_robin" then
      resource["lb_policy"] = "ROUND_ROBIN"
    elseif options["api_backend"]["balance_algorithm"] == "ip_hash" then
      resource["lb_policy"] = "RING_HASH"
    end

    servers = options["api_backend"]["servers"]

    if options["api_backend"]["backend_protocol"] == "https" then
      tls_sni =  options["api_backend"]["backend_host"]
    end
  end

  if options["website_backend"] then
    resource["lb_policy"] = "LEAST_REQUEST"

    servers = {
      {
        host = options["website_backend"]["server_host"],
        port = options["website_backend"]["server_port"]
      },
    }

    if options["website_backend"]["backend_protocol"] == "https" then
      tls_sni = options["website_backend"]["_backend_host"]
    end
  end

  if servers then
    local any_servers_ipv6 = false
    local any_servers_hostname = false

    for _, server in ipairs(servers) do
      local host = server["host"]
      if string.find(host, ":", nil, true) then
        any_servers_ipv6 = true
        server["_host_type"] = "ipv6"
      else
        local find_from, _, find_err = re_find(host, [[^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$]], "jo")
        if find_err then
          ngx.log(ngx.ERR, "regex error: ", find_err)
        end

        if find_from then
          server["_host_type"] = "ipv4"
        else
          any_servers_hostname = true
          server["_host_type"] = "hostname"
        end
      end
    end

    -- Envoy does not currently support a mixture of IPv6 and hostnames:
    --
    -- https://github.com/envoyproxy/envoy/issues/18606
    -- https://github.com/envoyproxy/envoy/pull/18945
    --
    -- If only IP addresses are detected, then use Envoy's "STATIC" mode to
    -- properly connect to IPv6 addresses. But if there is a mixture of IPv6
    -- and hostnames, ignore the IPv6 addresses, and just use the hostnames as
    -- a temporary workaround (but hopefully we can revisit this once this is
    -- fixed in Envoy).
    if any_servers_ipv6 then
      if not any_servers_hostname then
        resource["type"] = "STATIC"
      end
    end

    for _, server in ipairs(servers) do
      if any_servers_ipv6 and any_servers_hostname and server["_host_type"] == "ipv6" then
        ngx.log(ngx.WARN, "API backend '" .. resource["name"] .. "' has a mixture of IPv6 and non-IPv6 servers. This configuration is not yet supported. Ignoring IPv6 servers.")
      else
        table.insert(resource["load_assignment"]["endpoints"]["lb_endpoints"], {
          endpoint = {
            address = {
              socket_address = {
                address = server["host"],
                port_value = server["port"],
              },
            },
          },
        })
      end
    end
  end

  if tls_sni then
    resource["transport_socket"] = {
      name = "envoy.transport_sockets.tls",
      typed_config = {
        ["@type"] = "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext",
        sni = tls_sni,
        common_tls_context = {
          tls_params = {
            cipher_suites = file_config["envoy"]["tls_cipher_suites"],
            ecdh_curves = file_config["envoy"]["tls_ecdh_curves"],
          },
        },
      },
    }
  end

  return resource
end

local function build_virtual_host_resource(options)
  local virtual_host = {
    name = options["domain"],
    domains = { options["domain"] },
    routes = {
      match = {
        prefix = "/",
      },
      route = {
        cluster = options["cluster"],
        host_rewrite_header = "x-api-umbrella-backend-host",
        timeout = file_config["envoy"]["_route_timeout"],
      },
    },
    retry_policy = {
      -- Retry connections if the connection was never established (eg, if the
      -- API backend was temporarily down or a keepalive connection was
      -- killed).
      retry_on = "connect-failure,reset,http3-post-connect-failure",
      num_retries = 2,
    },
  }

  return virtual_host
end

local function build_cds(config_version)
  local cds = {
    version_info = config_version,
    resources = {},
  }

  return cds
end

local function build_lds(config_version, rds_path)
  local access_log = {
    name = "envoy.access_loggers.file",
    typed_config = {
      log_format = {
        json_format = {
          time = "%START_TIME%",
          ip = "%REQ(X-FORWARDED-FOR)%",
          method = "%REQ(:METHOD)%",
          uri = "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",
          proto = "%PROTOCOL%",
          status = "%RESPONSE_CODE%",
          user_agent = "%REQ(USER-AGENT)%",
          id = "%REQ(X-API-UMBRELLA-REQUEST-ID)%",
          cache = "%REQ(X-CACHE)%",
          host = "%REQ(:AUTHORITY)%",
          resp_size = "%BYTES_SENT%",
          req_size = "%BYTES_RECEIVED%",
          duration = "%DURATION%",
          req_duration = "%REQUEST_DURATION%",
          resp_duration = "%RESPONSE_DURATION%",
          resp_flags = "%RESPONSE_FLAGS%",
          resp_detail = "%RESPONSE_CODE_DETAILS%",
          con_details = "%CONNECTION_TERMINATION_DETAILS%",
          up_attempts = "%UPSTREAM_REQUEST_ATTEMPT_COUNT%",
          up_host = "%UPSTREAM_HOST%",
          up_fail = "%UPSTREAM_TRANSPORT_FAILURE_REASON%",
        },
        omit_empty_values = true,
      },
    },
  }

  if file_config["log"]["destination"] == "console" then
    access_log["typed_config"]["@type"] = "type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog"
  else
    access_log["typed_config"]["@type"] = "type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog"
    access_log["typed_config"]["path"] = path_join(file_config["log_dir"], "envoy/access.log")
  end

  local lds = {
    version_info = config_version,
    resources = {
      {
        ["@type"] = "type.googleapis.com/envoy.config.listener.v3.Listener",
        name = "listener",
        address = {
          socket_address = {
            address = file_config["envoy"]["host"],
            port_value = file_config["envoy"]["port"],
          },
        },
        filter_chains = {
          {
            filters = {
              {
                name = "envoy.http_connection_manager",
                typed_config = {
                  ["@type"] = "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
                  stat_prefix = "router",
                  common_http_protocol_options = {
                    max_headers_count = 200,
                    idle_timeout = "120s",
                  },
                  generate_request_id = false,
                  server_header_transformation = "PASS_THROUGH",
                  http_filters = {
                    {
                      name = "envoy.filters.http.router",
                      typed_config = {
                        ["@type"] = "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router",
                      },
                    },
                  },
                  rds = {
                    config_source = {
                      path_config_source = {
                        path = rds_path,
                      },
                      resource_api_version = "V3",
                    },
                  },
                  stream_idle_timeout = file_config["envoy"]["_stream_idle_timeout"],
                  access_log = access_log,

                  -- Enable this option, since Envoy is sitting behind other
                  -- proxies.
                  -- https://www.envoyproxy.io/docs/envoy/latest/configuration/best_practices/level_two#best-practices-level2
                  -- https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/filters/network/http_connection_manager/v3/http_connection_manager.proto#envoy-v3-api-field-extensions-filters-network-http-connection-manager-v3-httpconnectionmanager-stream-error-on-invalid-http-message
                  stream_error_on_invalid_http_message = true,
                },
              },
            },
          },
        },
      },
    },
  }

  return lds
end

local function build_rds(config_version)
  local rds = {
    version_info = config_version,
    resources = {
      ["@type"] = "type.googleapis.com/envoy.config.route.v3.RouteConfiguration",
      virtual_hosts = {},
      request_headers_to_remove = {
        "x-envoy-expected-rq-timeout-ms",
        "x-envoy-internal",

        -- Note: This backend host header isn't necessary for backends to
        -- receive and ideally we'd strip it. However, removing it breaks our
        -- ability to use it in the "host_rewrite_header" option. So we will
        -- pass it along to API backends unless Envoy allows for better
        -- ordering of this in the future.
        -- "x-api-umbrella-backend-host",
      },
      response_headers_to_remove = {
        "x-envoy-upstream-service-time",
      },
      response_headers_to_add = {
        {
          append_action = "OVERWRITE_IF_EXISTS_OR_ADD",
          header = {
            key = "x-api-umbrella-backend-resolved-host",
            value = "%UPSTREAM_HOST%",
          },
        },
        {
          append_action = "OVERWRITE_IF_EXISTS_OR_ADD",
          header = {
            key = "x-api-umbrella-backend-response-code-details",
            value = "%RESPONSE_CODE_DETAILS%",
          },
        },
        {
          append_action = "OVERWRITE_IF_EXISTS_OR_ADD",
          header = {
            key = "x-api-umbrella-backend-response-flags",
            value = "%RESPONSE_FLAGS%",
          },
        },
      },
    },
  }

  return rds
end

local function populate_backend_resources(active_config, cds, rds)
  for _, api_backend in ipairs(active_config["api_backends"]) do
    local cluster_resource = build_cluster_resource("api-backend-cluster-" .. api_backend["id"], {
      api_backend = api_backend,
    })
    table.insert(cds["resources"], cluster_resource)

    local virtual_host_resource = build_virtual_host_resource({
      domain = "api-backend-" .. api_backend["id"],
      cluster = cluster_resource["name"],
    })
    table.insert(rds["resources"]["virtual_hosts"], virtual_host_resource)
  end

  for _, website_backend in ipairs(active_config["website_backends"]) do
    local cluster_resource = build_cluster_resource("website-backend-cluster-" .. website_backend["id"], {
      website_backend = website_backend,
    })
    table.insert(cds["resources"], cluster_resource)

    local virtual_host_resource = build_virtual_host_resource({
      domain = "website-backend-" .. website_backend["id"],
      cluster = cluster_resource["name"],
    })
    table.insert(rds["resources"]["virtual_hosts"], virtual_host_resource)
  end
end

local function wait_for_live_config(config_version, cds)
  local httpc = http.new()
  local connect_ok, connect_err = httpc:connect({
    scheme = "http",
    host = file_config["envoy"]["admin"]["host"],
    port = file_config["envoy"]["admin"]["port"],
  })

  if not connect_ok then
    httpc:close()
    return nil, "envoy admin connect error: " .. (connect_err or "")
  end

  local ready = false
  local ready_err
  local versions_ready = false
  local clusters_ready = false
  for _ = 1, 50 do
    if not versions_ready then
      local stats_res, stats_err = httpc:request({
        method = "GET",
        path = "/stats?format=json&filter=\\.version_text$",
      })
      if stats_err then
        httpc:close()
        return nil, "envoy admin request error: " .. (stats_err or "")
      end

      local stats_body, stats_body_err = stats_res:read_body()
      if stats_body_err then
        httpc:close()
        return nil, "envoy admin read body error: " .. (stats_body_err or "")
      end

      local stats = json_decode(stats_body)
      for _, stat in ipairs(stats["stats"]) do
        if stat["value"] == config_version then
          versions_ready = true
        else
          versions_ready = false
          ready_err = stat["name"] .. " version: " .. stat["value"]
          break
        end
      end
    end

    if not clusters_ready then
      local clusters_res, clusters_err = httpc:request({
        method = "GET",
        path = "/clusters?format=json",
      })
      if clusters_err then
        httpc:close()
        return nil, "envoy admin request error: " .. (clusters_err or "")
      end

      local clusters_body, clusters_body_err = clusters_res:read_body()
      if clusters_body_err then
        httpc:close()
        return nil, "envoy admin read body error: " .. (clusters_body_err or "")
      end

      local clusters = json_decode(clusters_body)
      local initialized_cluster_names = {}
      for _, cluster in ipairs(clusters["cluster_statuses"]) do
        initialized_cluster_names[cluster["name"]] = true
      end
      for _, cluster in ipairs(cds["resources"]) do
        if not initialized_cluster_names[cluster["name"]] then
          clusters_ready = false
          ready_err = "cluster not initialized: " .. cluster["name"]
          break
        else
          clusters_ready = true
        end
      end
    end

    if versions_ready and clusters_ready then
      ready = true
      break
    else
      sleep(0.1)
    end
  end

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    httpc:close()
    return nil, "envoy admin keepalive error: " .. (keepalive_err or "")
  end

  if not ready then
    return nil, "envoy admin timed out waiting for configuration to be live. Waiting for: " .. (config_version or "") .. ", " .. (ready_err or "")
  end
end

return function(active_config)
  local cds_path = path_join(file_config["run_dir"], "envoy/cds.json")
  local lds_path = path_join(file_config["run_dir"], "envoy/lds.json")
  local rds_path = path_join(file_config["run_dir"], "envoy/rds.json")

  local cds = build_cds(active_config["version"])
  local lds = build_lds(active_config["version"], rds_path)
  local rds = build_rds(active_config["version"])

  populate_backend_resources(active_config, cds, rds)

  writefile(cds_path .. ".tmp", json_encode(cds))
  writefile(lds_path .. ".tmp", json_encode(lds))
  writefile(rds_path .. ".tmp", json_encode(rds))

  -- Push live in order described here:
  -- https://www.envoyproxy.io/docs/envoy/v1.21.1/api-docs/xds_protocol.html#eventual-consistency-considerations
  os.rename(cds_path .. ".tmp", cds_path)
  os.rename(lds_path .. ".tmp", lds_path)
  os.rename(rds_path .. ".tmp", rds_path)

  wait_for_live_config(active_config["version"], cds)
end
