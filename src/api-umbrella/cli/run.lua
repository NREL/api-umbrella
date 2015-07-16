local config = {}
local template_config = {}

local array_includes = require "api-umbrella.utils.array_includes"
local array_last = require "api-umbrella.utils.array_last"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local dir = require "pl.dir"
local file = require "pl.file"
local inspect = require "inspect"
local lustache = require "lustache"
local lyaml = require "lyaml"
local mustache_unescape = require "api-umbrella.utils.mustache_unescape"
local nillify_yaml_nulls = require "api-umbrella.utils.nillify_yaml_nulls"
local path = require "pl.path"
local plutils = require "pl.utils"
local posix = require "posix"
local stat = require "posix.sys.stat"
local tablex = require "pl.tablex"
local types = require "pl.types"
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
    ["_user?"] = not types.is_empty(config["user"]),
    ["_group?"] = not types.is_empty(config["group"]),
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
  if config["_user?"] then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to change user to '" .. config["user"] .. "'")
      os.exit(1)
    end

    if os.execute("getent passwd " .. config["user"] .. " &> /dev/null") ~= 0 then
      print("User '", config["user"], "' does not exist")
      os.exit(1)
    end
  end

  if config["_group?"] then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to change group to '" .. config["group"] .. "'")
      os.exit(1)
    end

    if os.execute("getent group " .. config["group"] .. " &> /dev/null") ~= 0 then
      print("Group '" .. config["group"] .. "' does not exist")
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

local function write_templates()
  local template_root = path.join(app_root, "templates/etc")
  for root, dirs, files in dir.walk(template_root) do
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

  unistd.chown(path.join(config["root_dir"], "var/trafficserver"), config["user"], config["group"])
  unistd.chown(path.join(config["log_dir"], "trafficserver"), config["user"], config["group"])
  os.execute("chown -R " .. config["user"] .. ":" .. config["group"] .. " " .. path.join(config["etc_dir"], "trafficserver"))

  local perp_service_dirs = dir.getdirectories(path.join(config["etc_dir"], "perp"))
  for _, service_dir in ipairs(perp_service_dirs) do
    local is_hidden = (string.find(path.basename(service_dir), ".", 1, true) == 1)
    if not is_hidden then
      os.execute("chmod +t " .. service_dir)
    end
  end
end

local function start_perp(options)
  local perp_base = path.join(config["etc_dir"], "perp")
  local args = {
    "-0", "api-umbrella (perpboot)",
    "-P", "/tmp/perpboot.lock",
    "perpboot",
    perp_base
  }

  if options and options["background"] then
    table.insert(args, "-d")
  end

  unistd.execp("runtool", args)

  -- execp should replace the current process, so we've gotten this far it
  -- means execp failed, likely due to the "runtool" command not being found.
  print("Error: runtool command was not found")
  os.exit(1)
end

return function(options)
  read_default_config()
  read_system_config()
  set_computed_config()
  set_template_config()
  permission_check()
  write_runtime_config()
  prepare()
  write_templates()
  set_permissions()
  start_perp(options)
end
