local array_includes = require "api-umbrella.utils.array_includes"
local array_last = require "api-umbrella.utils.array_last"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local dir = require "pl.dir"
local file = require "pl.file"
local lyaml = require "lyaml"
local nillify_yaml_nulls = require "api-umbrella.utils.nillify_yaml_nulls"
local path = require "pl.path"
local plutils = require "pl.utils"
local random_token = require "api-umbrella.utils.random_token"
local stringx = require "pl.stringx"
local types = require "pl.types"

local is_empty = types.is_empty
local split = plutils.split
local strip = stringx.strip

local config

local src_root_dir = os.getenv("API_UMBRELLA_SRC_ROOT")
local embedded_root_dir = os.getenv("API_UMBRELLA_EMBEDDED_ROOT")

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
  end
end

local function read_default_config()
  local content = file.read(path.join(src_root_dir, "config/default.yml"), true)
  config = lyaml.load(content)
end

local function read_system_config()
  local content = file.read(os.getenv("API_UMBRELLA_CONFIG") or "/etc/api-umbrella/api-umbrella.yml", true)
  if content then
    local overrides = lyaml.load(content)
    deep_merge_overwrite_arrays(config, overrides)
  end

  nillify_yaml_nulls(config)
end

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

  if not config["static_site"]["api_key"] then
    local static_site_api_key_path = path.join(config["run_dir"], "static-site-api-key")
    local api_key = file.read(static_site_api_key_path)
    if not api_key then
      api_key = random_token(40)
    end

    config["static_site"]["api_key"] = api_key
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

  deep_merge_overwrite_arrays(config, {
    _embedded_root_dir = embedded_root_dir,
    _src_root_dir = src_root_dir,
    _package_path = package.path,
    _package_cpath = package.cpath,
    mongodb = {
      _database = array_last(plutils.split(config["mongodb"]["url"], "/")),
    },
    elasticsearch = {
      _first_host = config["elasticsearch"]["hosts"][1],
    },
    ["_service_general_db_enabled?"] = array_includes(config["services"], "general_db"),
    ["_service_log_db_enabled?"] = array_includes(config["services"], "log_db"),
    ["_service_router_enabled?"] = array_includes(config["services"], "router"),
    ["_service_web_enabled?"] = array_includes(config["services"], "web"),
    router = {
      trusted_proxies = trusted_proxies,
    },
    gatekeeper = {
      dir = src_root_dir,
    },
    web = {
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

  if config["app_env"] == "test" then
    config["_test_env_install_dir"] = path.join(path.dirname(embedded_root_dir), "test-env")
  end
end

local function write_runtime_config()
  local runtime_config_path = path.join(config["run_dir"], "runtime_config.yml")
  dir.makepath(path.dirname(runtime_config_path))
  file.write(runtime_config_path, lyaml.dump({config}))
end

return function(options)
  if not config then
    read_runtime_config()
  end

  if not config or (options and options["write"]) then
    read_default_config()
    read_system_config()
    set_computed_config()

    if options and options["write"] then
      write_runtime_config()
    end
  end

  return config
end
