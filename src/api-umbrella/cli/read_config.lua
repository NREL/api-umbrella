local array_includes = require "api-umbrella.utils.array_includes"
local array_last = require "api-umbrella.utils.array_last"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local dir = require "pl.dir"
local file = require "pl.file"
local host_normalize = require "api-umbrella.utils.host_normalize"
local lyaml = require "lyaml"
local nillify_yaml_nulls = require "api-umbrella.utils.nillify_yaml_nulls"
local path = require "pl.path"
local plutils = require "pl.utils"
local random_token = require "api-umbrella.utils.random_token"
local stringx = require "pl.stringx"
local types = require "pl.types"
local url = require "socket.url"

local is_empty = types.is_empty
local split = plutils.split
local strip = stringx.strip
local url_parse = url.parse

local config

local src_root_dir = os.getenv("API_UMBRELLA_SRC_ROOT")
local embedded_root_dir = os.getenv("API_UMBRELLA_EMBEDDED_ROOT")

-- Fetch the DNS nameservers in use on this server out of the /etc/resolv.conf
-- file.
local function read_resolv_conf_nameservers()
  local nameservers = {}

  local resolv_path = "/etc/resolv.conf"
  local resolv_file, err = io.open(resolv_path, "r")
  if err then
    print("failed to open file: ", err)
  else
    for line in resolv_file:lines() do
      local nameserver = string.match(line, "^%s*nameserver%s+(.+)$")
      if nameserver then
        nameserver = strip(nameserver)
        if not is_empty(nameserver) then
          table.insert(nameservers, nameserver)
        end
      end
    end

    resolv_file:close()
  end

  return nameservers
end

-- Fetch any local /etc/hosts aliases in place on this server (for use in
-- resolving things like "localhost" and other potential aliases).
local function read_etc_hosts()
  local hosts = {}

  local hosts_path = "/etc/hosts"
  local hosts_file, err = io.open(hosts_path, "r")
  if err then
    print("failed to open file: ", err)
  else
    for line in hosts_file:lines() do
      local parts = split(line, "%s+", false, 2)
      if parts then
        local ip = parts[1]
        local ip_hosts = parts[2]
        if ip and ip_hosts then
          ip = strip(ip)
          ip_hosts = split(strip(ip_hosts), "%s+")
          if not is_empty(ip) and not is_empty(ip_hosts) then
            for _, host in ipairs(ip_hosts) do
              hosts[host] = ip
            end
          end
        end
      end
    end

    hosts_file:close()
  end

  return hosts
end

-- Read the runtime config file. This is a fully combined and merged config
-- file that reflects the active configuration that is available to a running
-- API Umbrella process.
--
-- This combines the default config with server-specific overrides
-- (/etc/api-umbrella/api-umbrella.yml), along with internally computed config
-- variables.
local function read_runtime_config()
  local runtime_config_path = os.getenv("API_UMBRELLA_RUNTIME_CONFIG")
  if runtime_config_path then
    local f, err = io.open(runtime_config_path, "rb")
    if err then
      print("Could not open config file '" .. runtime_config_path .. "'")
      os.exit(1)
    end

    local content = f:read("*all")
    f:close()

    config = lyaml.load(content)
    nillify_yaml_nulls(config)
  end
end

-- Read the default, global config for API Umbrella defined in the internal
-- config/default.yml file.
local function read_default_config()
  local content = file.read(path.join(src_root_dir, "config/default.yml"), true)
  config = lyaml.load(content)
  nillify_yaml_nulls(config)
end

-- Handle setup of random secret tokens that should be be unique for API
-- Umbrella installations, but should be persisted across restarts.
--
-- In a multi-server setup, these secret tokens will likely need to be
-- explicitly given in the server's /etc/api-umbrella/api-umbrella.yml file so
-- the secrets match across servers, but this provides defaults for a
-- single-server installation.
local function set_cached_random_tokens()
  -- Generate random tokens for this server.
  local cached = {
    web = {
      rails_secret_token = random_token(128),
    },
    static_site = {
      api_key = random_token(40),
    },
  }

  -- See if there were any previous values for these random tokens on this
  -- server. If so, use any of those values that might be present instead.
  local file_path = path.join(os.getenv("API_UMBRELLA_ROOT") or "/opt/api-umbrella", "var/run/cached_random_config_values.yml")
  local content = file.read(file_path, true)
  if content then
    deep_merge_overwrite_arrays(cached, lyaml.load(content))
  end

  -- Persist whatever the state of the tokens is now.
  file.write(file_path, lyaml.dump({cached}))

  -- Merge these random tokens onto the config. Note that this happens before
  -- we read the system config (/etc/api-umbrella/api-umbrella.yml), so if
  -- these values are defined there, these random values will be overwritten.
  deep_merge_overwrite_arrays(config, cached)
end

-- Read the /etc/api-umbrella/api-umbrella.yml config file that provides
-- server-specific overrides for API Umbrella configuration.
local function read_system_config()
  local config_paths = os.getenv("API_UMBRELLA_CONFIG") or "/etc/api-umbrella/api-umbrella.yml"
  config_paths = split(config_paths, ":", true)
  for _, config_path in ipairs(config_paths) do
    if path.exists(config_path) then
      local content = file.read(config_path, true)
      if content then
        local overrides = lyaml.load(content)
        deep_merge_overwrite_arrays(config, overrides)
        nillify_yaml_nulls(config)
      end
    else
      print("WARNING: Config file does not exist: ", config_path)
    end
  end

  nillify_yaml_nulls(config)
end

-- After all the primary config is read from files and combined, perform
-- additional setup for configuration variables that are computed based on
-- other configuration variables. Since these values are computed, they
-- typically aren't subject to defining or overriding in any of the config
-- files.
--
-- For configuration variables that are computed and the user cannot override
-- in the config files, we denote those with an underscore prefix in the name.
local function set_computed_config()
  if not config["root_dir"] then
    config["root_dir"] = os.getenv("API_UMBRELLA_ROOT") or "/opt/api-umbrella"
  end

  if not config["etc_dir"] then
    config["etc_dir"] = path.join(config["root_dir"], "etc")
  end

  if not config["log_dir"] then
    config["log_dir"] = path.join(config["root_dir"], "var/log")
  end

  if not config["run_dir"] then
    config["run_dir"] = path.join(config["root_dir"], "var/run")
  end

  if not config["tmp_dir"] then
    config["tmp_dir"] = path.join(config["root_dir"], "var/tmp")
  end

  if not config["db_dir"] then
    config["db_dir"] = path.join(config["root_dir"], "var/db")
  end

  local trusted_proxies = config["router"]["trusted_proxies"] or {}
  if not array_includes(trusted_proxies, "127.0.0.1") then
    table.insert(trusted_proxies, "127.0.0.1")
  end

  if not config["hosts"] then
    config["hosts"] = {}
  end

  local default_host_exists = false
  for _, host in ipairs(config["hosts"]) do
    if host["default"] then
      default_host_exists = true
    end

    if host["hostname"] == "*" then
      host["_nginx_server_name"] = "_"
    else
      host["_nginx_server_name"] = host["hostname"]
    end
  end

  -- Add a default fallback host that will match any hostname, but doesn't
  -- include any host-specific settings in nginx (like rewrites). This host can
  -- still then be used to match APIs for unknown hosts.
  table.insert(config["hosts"], {
    hostname = "*",
    _nginx_server_name = "_",
    default = (not default_host_exists),
  })

  local default_hostname
  if config["hosts"] then
    for _, host in ipairs(config["hosts"]) do
      if host["default"] and host["hostname"] then
        default_hostname = host["hostname"]
        break
      end
    end
  end

  if default_hostname then
    config["_default_hostname"] = default_hostname
    config["_default_hostname_normalized"] = host_normalize(default_hostname)
  end

  -- Determine the nameservers for DNS resolution. Prefer explicitly configured
  -- nameservers, but fallback to nameservers defined in resolv.conf, and then
  -- Google's DNS servers if nothing else is defined.
  local nameservers
  if config["dns_resolver"] and config["dns_resolver"]["nameservers"] then
    nameservers = config["dns_resolver"]["nameservers"]
  end
  if is_empty(nameservers) then
    nameservers = read_resolv_conf_nameservers()
  end
  if is_empty(nameservers) then
    nameservers = { "8.8.8.8", "8.8.4.4" }
  end

  -- Parse the nameservers, allowing for custom DNS ports to be specified in
  -- the OpenBSD resolv.conf format of "[IP]:port".
  config["dns_resolver"]["_nameservers"] = {}
  config["dns_resolver"]["_nameservers_nginx"] = {}
  for _, nameserver in ipairs(nameservers) do
    local ip, port = string.match(nameserver, "^%[(.+)%]:(%d+)$")
    if ip and port then
      nameserver = { ip, port }
      table.insert(config["dns_resolver"]["_nameservers_nginx"], ip .. ":" .. port)
    else
      table.insert(config["dns_resolver"]["_nameservers_nginx"], nameserver)
    end

    table.insert(config["dns_resolver"]["_nameservers"], nameserver)
  end
  config["dns_resolver"]["_nameservers_nginx"] = table.concat(config["dns_resolver"]["_nameservers_nginx"], " ")
  config["dns_resolver"]["nameservers"] = nil

  config["dns_resolver"]["_etc_hosts"] = read_etc_hosts()

  config["elasticsearch"]["_servers"] = {}
  if config["elasticsearch"]["hosts"] then
    for _, elasticsearch_url in ipairs(config["elasticsearch"]["hosts"]) do
      local parsed, parse_err = url_parse(elasticsearch_url)
      if not parsed or parse_err then
        print("failed to parse: ", elasticsearch_url, parse_err)
      else
        parsed["port"] = tonumber(parsed["port"])
        if not parsed["port"] then
          if parsed["scheme"] == "https" then
            parsed["port"] = 443
          elseif parsed["scheme"] == "http" then
            parsed["port"] = 80
          end
        end

        table.insert(config["elasticsearch"]["_servers"], parsed)
      end
    end
  end

  if not config["analytics"]["outputs"] then
    config["analytics"]["outputs"] = { config["analytics"]["adapter"] }
  end

  config["kafka"]["_rsyslog_broker"] = {}
  for _, broker in ipairs(config["kafka"]["brokers"]) do
    table.insert(config["kafka"]["_rsyslog_broker"], '"' .. broker["host"] .. ":" .. broker["port"] .. '"')
  end
  config["kafka"]["_rsyslog_broker"] = table.concat(config["kafka"]["_rsyslog_broker"], ",")

  -- Setup the request/response timeouts for the different pieces of the stack.
  -- Since we traverse multiple proxies, we want to make sure the timeouts of
  -- the different proxies are kept in sync.
  --
  -- We will actually stagger the timeouts slightly at each proxy layer to
  -- prevent race conditions. Since the flow of the requests looks like:
  --
  -- [incoming request] => [initial nginx proxy] => [trafficserver] => [api routing nginx proxy] => [api backends]
  --
  -- Our real timeouts defined in the config file will be enforced at the "api
  -- routing nginx proxy" layer. We increase our timeouts on the proxies
  -- further out to prevent race conditions if all the pieces of the stack
  -- timeout at the exact same time. This results in a timeout error regardless
  -- of which stack returns the timeout error, but by staggering them, it makes
  -- it more predictable and easier to test against if we always know the api
  -- router is what should trigger the initial timeout. This also prevents the
  -- proxies further back in the stack from thinking the client unexpectedly
  -- hung up on the request.
  config["trafficserver"]["_connect_attempts_timeout"] = config["nginx"]["proxy_read_timeout"] + 1
  config["trafficserver"]["_transaction_no_activity_timeout_out"] = config["nginx"]["proxy_read_timeout"] + 1
  config["trafficserver"]["_transaction_no_activity_timeout_in"] = config["nginx"]["proxy_read_timeout"] + 1
  config["nginx"]["_initial_proxy_connect_timeout"] = config["nginx"]["proxy_connect_timeout"] + 2
  config["nginx"]["_initial_proxy_read_timeout"] = config["nginx"]["proxy_read_timeout"] + 2
  config["nginx"]["_initial_proxy_send_timeout"] = config["nginx"]["proxy_send_timeout"] + 2

  deep_merge_overwrite_arrays(config, {
    _embedded_root_dir = embedded_root_dir,
    _src_root_dir = src_root_dir,
    _package_path = package.path,
    _package_cpath = package.cpath,
    analytics = {
      ["_output_elasticsearch?"] = array_includes(config["analytics"]["outputs"], "elasticsearch"),
      ["_output_kylin?"] = array_includes(config["analytics"]["outputs"], "kylin"),
    },
    mongodb = {
      _database = plutils.split(array_last(plutils.split(config["mongodb"]["url"], "/", true)), "?", true)[1],
    },
    elasticsearch = {
      _first_server = config["elasticsearch"]["_servers"][1],
    },
    ["_service_general_db_enabled?"] = array_includes(config["services"], "general_db"),
    ["_service_log_db_enabled?"] = array_includes(config["services"], "log_db"),
    ["_service_hadoop_db_enabled?"] = array_includes(config["services"], "hadoop_db"),
    ["_service_router_enabled?"] = array_includes(config["services"], "router"),
    ["_service_web_enabled?"] = array_includes(config["services"], "web"),
    ["_service_nginx_reloader_enabled?"] = (array_includes(config["services"], "router") and config["nginx"]["_reloader_frequency"]),
    router = {
      trusted_proxies = trusted_proxies,
    },
    gatekeeper = {
      dir = src_root_dir,
    },
    web = {
      admin = {
        auth_strategies = {
          ["_local_enabled?"] = array_includes(config["web"]["admin"]["auth_strategies"]["enabled"], "local"),
          ["_only_ldap_enabled?"] = (#config["web"]["admin"]["auth_strategies"]["enabled"] == 1 and config["web"]["admin"]["auth_strategies"]["enabled"][1] == "ldap"),
        },
      },
      dir = path.join(src_root_dir, "src/api-umbrella/web-app"),
      puma = {
        bind = "unix://" .. config["run_dir"] .. "/puma.sock",
      },
    },
    static_site = {
      dir = path.join(embedded_root_dir, "apps/static-site/current"),
      build_dir = path.join(embedded_root_dir, "apps/static-site/current/build"),
    },
  })

  if config["app_env"] == "development" then
    config["_dev_env_install_dir"] = path.join(src_root_dir, "build/work/dev-env")
  end

  if config["app_env"] == "test" then
    config["_test_env_install_dir"] = path.join(src_root_dir, "build/work/test-env")
  end
end

-- Write out the combined and merged config to the runtime file.
--
-- This runtime config reflects the full state of the available config and can
-- be used by other API Umbrella processes for reading the config (without
-- having to actually merge and combine again).
local function write_runtime_config()
  local runtime_config_path = path.join(config["run_dir"], "runtime_config.yml")
  dir.makepath(path.dirname(runtime_config_path))
  file.write(runtime_config_path, lyaml.dump({config}))
end

return function(options)
  -- If fetching config for the first time in this process, try to load the
  -- runtime file for the existing combined/merged config.
  if not config then
    read_runtime_config()
  end

  -- If no runtime config is present, or if we're forcing a runtime config
  -- write (such as during a reload), then do all parsing & merging before
  -- writing the runtime config.
  if not config or (options and options["write"]) then
    read_default_config()
    set_cached_random_tokens()
    read_system_config()
    set_computed_config()

    if options and options["write"] then
      write_runtime_config()
    end
  end

  return config
end
