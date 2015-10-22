local config
local template_config

local array_includes = require "api-umbrella.utils.array_includes"
local array_last = require "api-umbrella.utils.array_last"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local dir = require "pl.dir"
local file = require "pl.file"
local lustache = require "lustache"
local lyaml = require "lyaml"
local mustache_unescape = require "api-umbrella.utils.mustache_unescape"
local nillify_yaml_nulls = require "api-umbrella.utils.nillify_yaml_nulls"
local path = require "pl.path"
local plutils = require "pl.utils"
local posix = require "posix"
local random_token = require "api-umbrella.utils.random_token"
local run_command = require "api-umbrella.utils.run_command"
local stat = require "posix.sys.stat"
local tablex = require "pl.tablex"
local unistd = require "posix.unistd"

local src_root_dir = os.getenv("API_UMBRELLA_SRC_ROOT")
local embedded_root_dir = os.getenv("API_UMBRELLA_EMBEDDED_ROOT")

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

local function set_template_config()
  local runtime_config_path = path.join(config["run_dir"], "runtime_config.yml")

  template_config = tablex.deepcopy(config)
  deep_merge_overwrite_arrays(template_config, {
    _api_umbrella_config_runtime_file = runtime_config_path,
    ["_test_env?"] = (config["app_env"] == "test"),
    ["_development_env?"] = (config["app_env"] == "development"),
    _mongodb_yaml = lyaml.dump({deep_merge_overwrite_arrays({
      storage = {
        dbPath = path.join(config["db_dir"], "mongodb"),
      },
    }, config["mongodb"]["embedded_server_config"])}),
    _elasticsearch_yaml = lyaml.dump({deep_merge_overwrite_arrays({
      path = {
        conf = path.join(config["etc_dir"], "elasticsearch"),
        data = path.join(config["db_dir"], "elasticsearch"),
        logs = config["log_dir"],
      },
    }, config["elasticsearch"]["embedded_server_config"])})
  })
end

local function permission_check()
  local effective_uid = unistd.geteuid()
  if config["user"] then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to change user to '" .. config["user"] .. "'")
      os.exit(1)
    end

    local status, output, err = run_command("getent passwd " .. config["user"])
    if status == 2 and output == "" then
      print("User '", config["user"], "' does not exist")
      os.exit(1)
    elseif err then
      print(err)
      os.exit(1)
    end
  end

  if config["group"] then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to change group to '" .. config["group"] .. "'")
      os.exit(1)
    end

    local status, output, err = run_command("getent group " .. config["group"])
    if status == 2 and output == "" then
      print("Group '", config["group"], "' does not exist")
      os.exit(1)
    elseif err then
      print(err)
      os.exit(1)
    end
  end

  if config["http_port"] < 1024 or config["https_port"] < 1024 then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to use http ports below 1024")
      os.exit(1)
    end
  end

  if effective_uid == 0 then
    if not config["user"] or not config["group"] then
      print("Must define a user and group to run worker processes as when starting with with super-user privileges")
      os.exit(1)
    end
  end
end

local function write_runtime_config()
  local runtime_config_path = path.join(config["run_dir"], "runtime_config.yml")
  dir.makepath(path.dirname(runtime_config_path))
  file.write(runtime_config_path, lyaml.dump({config}))
end

local function prepare()
  local dirs = {
    config["db_dir"],
    config["log_dir"],
    config["run_dir"],
    config["tmp_dir"],
    path.join(config["db_dir"], "elasticsearch"),
    path.join(config["db_dir"], "mongodb"),
    path.join(config["etc_dir"], "trafficserver/snapshots"),
    path.join(config["log_dir"], "trafficserver"),
    path.join(config["root_dir"], "var/trafficserver"),
  }

  for _, directory in ipairs(dirs) do
    dir.makepath(directory)
  end
end

local function generate_self_signed_cert()
  local cert_required = false
  if config["hosts"] then
    for _, host in ipairs(config["hosts"]) do
      if not host["ssl_cert"] then
        cert_required = true
        break
      end
    end
  end

  if cert_required then
    local ssl_dir = path.join(config["etc_dir"], "ssl");
    local ssl_key_path = path.join(ssl_dir, "self_signed.key");
    local ssl_crt_path = path.join(ssl_dir, "self_signed.crt");

    if not path.exists(ssl_key_path) or not path.exists(ssl_crt_path) then
      dir.makepath(ssl_dir)
      local _, _, err = run_command("openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj '/C=/ST=/L=/O=API Umbrella/CN=apiumbrella.example.com' -keyout " .. ssl_key_path .. " -out " ..  ssl_crt_path)
      if err then
        print(err)
        os.exit(1)
      end
    end
  end
end

local function ensure_geoip_db()
  -- If the city db path doesn't exist, copy it from the package installation
  -- location to the runtime location (this path will then be overwritten by
  -- the auto-updater so we don't touch the original packaged file).
  local city_db_path = path.join(config["db_dir"], "geoip2/city.mmdb")
  if not path.exists(city_db_path) then
    local default_city_db_path = path.join(config["_embedded_root_dir"], "var/db/geoip2/city.mmdb")
    dir.makepath(path.dirname(city_db_path))
    file.copy(default_city_db_path, city_db_path)
  end
end

local function write_templates()
  local template_root = path.join(src_root_dir, "templates/etc")
  for root, _, files in dir.walk(template_root) do
    for _, filename in ipairs(files) do
      local template_path = path.join(root, filename)

      local is_hidden = (string.find(filename, ".", 1, true) == 1)
      local is_test_file = (string.find(template_path, "test-env") ~= nil)

      if not is_hidden and (not is_test_file or config["app_env"] == "test") then
        local install_path = string.gsub(template_path, "^" .. plutils.escape(template_root .. "/"), "", 1)
        install_path = string.gsub(install_path, plutils.escape(".mustache") .. "$", "", 1)
        install_path = path.join(config["etc_dir"], install_path)

        local content = file.read(template_path, true)

        local _, extension = path.splitext(template_path)
        if extension == ".mustache" then
          content = lustache:render(mustache_unescape(content), template_config)
        end

        dir.makepath(path.dirname(install_path))
        file.write(install_path, content)
        stat.chmod(install_path, stat.stat(template_path).st_mode)
      end
    end
  end
end

local function write_static_site_key()
  local static_site_api_key_path = path.join(config["run_dir"], "static-site-api-key")
  file.write(static_site_api_key_path, config["static_site"]["api_key"])

  local file_paths = {
    path.join(config["static_site"]["build_dir"], "contact/index.html"),
    path.join(config["static_site"]["build_dir"], "signup/index.html"),
  }
  for _, file_path in ipairs(file_paths) do
    local content = file.read(file_path)
    local new_content, replacements = string.gsub(content, "apiKey: '.-'", "apiKey: '" .. config["static_site"]["api_key"] .. "'")
    if replacements > 0 then
      file.write(file_path, new_content)
    end
  end
end

local function set_permissions()
  local _, err
  _, err = posix.chmod(config["tmp_dir"], "rwxrwxrwx")
  if err then
    print("chmod failed: ", err)
    os.exit(1)
  end

  if config["user"] and config["group"] then
    _, err = unistd.chown(path.join(config["root_dir"], "var/trafficserver"), config["user"], config["group"])
    if err then
      print("chown failed: ", err)
      os.exit(1)
    end

    _, err = unistd.chown(path.join(config["log_dir"], "trafficserver"), config["user"], config["group"])
    if err then
      print("chown failed: ", err)
      os.exit(1)
    end

    _, _, err = run_command("chown -R " .. config["user"] .. ":" .. config["group"] .. " " .. path.join(config["etc_dir"], "trafficserver"))
    if err then
      print(err)
      os.exit(1)
    end
  end
end

local function activate_services()
  local active_services = dir.getdirectories(path.join(src_root_dir, "templates/etc/perp"))
  tablex.transform(path.basename, active_services)

  -- Loop over the perp controlled services and set the sticky permission bit
  -- for any services that are supposed to be active (this sticky bit is how
  -- perp determines which services to run).
  local installed_service_dirs = dir.getdirectories(path.join(config["etc_dir"], "perp"))
  for _, service_dir in ipairs(installed_service_dirs) do
    local service_name = path.basename(service_dir)

    -- Disable any old services that might be installed, but are no longer
    -- present in templates/etc/perp.
    local is_active = array_includes(active_services, service_name)

    -- Disable any test-only services when not running in the test environment.
    if string.find(service_name, "test-env", 1, true) == 1 and config["app_env"] ~= "test" then
      is_active = false
    end

    -- Perp's hidden directories don't need the sticky bit.
    local is_hidden = (string.find(service_name, ".", 1, true) == 1)
    if is_hidden then
      is_active = false
    end

    -- Set the sticky bit for any active services.
    if is_active then
      local _, _, err = run_command("chmod +t " .. service_dir)
      if err then
        print(err)
        os.exit(1)
      end
    else
      local _, _, err = run_command("chmod -t " .. service_dir)
      if err then
        print(err)
        os.exit(1)
      end
    end
  end
end

return function()
  read_runtime_config()
  if not config then
    read_default_config()
    read_system_config()
    set_computed_config()
    write_runtime_config()
  end

  set_template_config()
  permission_check()
  prepare()
  generate_self_signed_cert()
  ensure_geoip_db()
  write_templates()
  write_static_site_key()
  set_permissions()
  activate_services()

  return config
end
