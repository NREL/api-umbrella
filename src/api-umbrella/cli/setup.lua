local config = {}
local template_config = {}

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
local run_command = require "api-umbrella.utils.run_command"
local stat = require "posix.sys.stat"
local tablex = require "pl.tablex"
local unistd = require "posix.unistd"

local app_root = os.getenv("API_UMBRELLA_SRC_ROOT")

local function read_default_config()
  local content = file.read(path.join(app_root, "config/default.yml"), true)
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

  deep_merge_overwrite_arrays(config, {
    _root_dir = os.getenv("API_UMBRELLA_ROOT"),
    _app_root = app_root,
    mongodb = {
      _database = array_last(plutils.split(config["mongodb"]["url"], "/")),
    },
    ["_service_general_db_enabled?"] = array_includes(config["services"], "general_db"),
    ["_service_log_db_enabled?"] = array_includes(config["services"], "log_db"),
    ["_service_router_enabled?"] = array_includes(config["services"], "router"),
    ["_service_web_enabled?"] = array_includes(config["services"], "web"),
    router = {
      trusted_proxies = trusted_proxies,
    },
  })

  if config["static_site"]["dir"] and not config["static_site"]["build_dir"] then
    deep_merge_overwrite_arrays(config, {
      static_site = {
        build_dir = path.join(config["static_site"]["dir"], "build"),
      },
    })
  end

  if config["app_env"] == "test" then
    deep_merge_overwrite_arrays(config, {
      gatekeeper = {
        dir = app_root,
      },
    })
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
    path.join(config["db_dir"], "beanstalkd"),
    path.join(config["db_dir"], "elasticsearch"),
    path.join(config["db_dir"], "mongodb"),
    path.join(config["db_dir"], "redis"),
    path.join(config["etc_dir"], "trafficserver/snapshots"),
    path.join(config["log_dir"], "trafficserver"),
    path.join(config["root_dir"], "var/trafficserver"),
    path.join(config["run_dir"], "varnish/api-umbrella"),
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

local function write_templates()
  local template_root = path.join(app_root, "templates/etc")
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

local function set_permissions()
  posix.chmod(config["tmp_dir"], "rwxrwxrwx")

  if config["user"] and config["group"] then
    unistd.chown(path.join(config["root_dir"], "var/trafficserver"), config["user"], config["group"])
    unistd.chown(path.join(config["log_dir"], "trafficserver"), config["user"], config["group"])
    local _, _, err = run_command("chown -R " .. config["user"] .. ":" .. config["group"] .. " " .. path.join(config["etc_dir"], "trafficserver"))
    if err then
      print(err)
      os.exit(1)
    end
  end

  local perp_service_dirs = dir.getdirectories(path.join(config["etc_dir"], "perp"))
  for _, service_dir in ipairs(perp_service_dirs) do
    local is_hidden = (string.find(path.basename(service_dir), ".", 1, true) == 1)
    if not is_hidden then
      local _, _, err = run_command("chmod +t " .. service_dir)
      if err then
        print(err)
        os.exit(1)
      end
    end
  end
end

return function()
  read_default_config()
  read_system_config()
  set_computed_config()
  set_template_config()
  permission_check()
  write_runtime_config()
  prepare()
  generate_self_signed_cert()
  write_templates()
  set_permissions()

  return config
end
