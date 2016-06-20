local array_includes = require "api-umbrella.utils.array_includes"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local dir = require "pl.dir"
local file = require "pl.file"
local lustache = require "lustache"
local lyaml = require "lyaml"
local mustache_unescape = require "api-umbrella.utils.mustache_unescape"
local path = require "pl.path"
local plutils = require "pl.utils"
local read_config = require "api-umbrella.cli.read_config"
local run_command = require "api-umbrella.utils.run_command"
local stat = require "posix.sys.stat"
local tablex = require "pl.tablex"
local unistd = require "posix.unistd"

local config
local template_config

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
        scripts = path.join(config["etc_dir"], "elasticsearch_scripts"),
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
      print("User '" .. (config["user"] or "") .. "' does not exist")
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
      print("Group '" .. (config["group"] or "") .. "' does not exist")
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

local function prepare()
  local dirs = {
    config["db_dir"],
    config["log_dir"],
    config["run_dir"],
    config["tmp_dir"],
    path.join(config["db_dir"], "elasticsearch"),
    path.join(config["db_dir"], "mongodb"),
    path.join(config["db_dir"], "rsyslog"),
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
  local city_db_path = path.join(config["db_dir"], "geoip/city-v6.dat")
  if not path.exists(city_db_path) then
    local default_city_db_path = path.join(config["_embedded_root_dir"], "var/db/geoip/city-v6.dat")
    dir.makepath(path.dirname(city_db_path))
    file.copy(default_city_db_path, city_db_path)
  end
end

local function write_templates()
  local template_root = path.join(config["_src_root_dir"], "templates/etc")
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
  local file_paths = {
    path.join(config["static_site"]["build_dir"], "contact/index.html"),
    path.join(config["static_site"]["build_dir"], "signup/index.html"),
  }
  for _, file_path in ipairs(file_paths) do
    if not path.exists(file_path) then
      print("File does not exist: " .. file_path)
      os.exit(1)
    end

    local content = file.read(file_path)
    local new_content, replacements = string.gsub(content, "apiKey: '.-'", "apiKey: '" .. config["static_site"]["api_key"] .. "'")
    if replacements > 0 then
      file.write(file_path, new_content)
    end
  end
end

local function set_permissions()
  local _, err
  _, _, err = run_command("chmod 1777 " .. config["tmp_dir"])
  if err then
    print("chmod failed: ", err)
    os.exit(1)
  end

  _, _, err = run_command("chmod 1777 " .. path.join(config["_src_root_dir"], "src/api-umbrella/web-app/tmp"))
  if err then
    print("chmod failed: ", err)
    os.exit(1)
  end

  if config["user"] and config["group"] then
    _, _, err = run_command("chown -R " .. config["user"] .. ":" .. config["group"] .. " " .. path.join(config["etc_dir"], "trafficserver") .. " " .. path.join(config["root_dir"], "var"))
    if err then
      print(err)
      os.exit(1)
    end
  end
end

local function activate_services()
  local active_services = dir.getdirectories(path.join(config["_src_root_dir"], "templates/etc/perp"))
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

    -- Disable services according to the broader service groups marked as
    -- enabled in api-umbrella.yml's "services" list.
    if is_active then
      if not config["_service_general_db_enabled?"] then
        if array_includes({ "mongod" }, service_name) then
          is_active = false
        end
      end

      if not config["_service_log_db_enabled?"] then
        if array_includes({ "elasticsearch" }, service_name) then
          is_active = false
        end
      end

      if not config["_service_hadoop_db_enabled?"] then
        if array_includes({ "flume", "kylin", "presto" }, service_name) then
          is_active = false
        end
      end

      if not config["_service_router_enabled?"] then
        if array_includes({ "geoip-auto-updater", "mora", "nginx", "rsyslog", "trafficserver" }, service_name) then
          is_active = false
        end
      end

      if not config["_service_web_enabled?"] then
        if array_includes({ "web-delayed-job", "web-puma" }, service_name) then
          is_active = false
        end
      end

      if not config["_service_nginx_reloader_enabled?"] then
        if array_includes({ "nginx-reloader" }, service_name) then
          is_active = false
        end
      end
    end

    -- Disable any test-only services when not running in the test environment.
    if string.find(service_name, "test-env", 1, true) == 1 then
      if config["app_env"] == "test" then
        is_active = true
      else
        is_active = false
      end
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
  config = read_config({ write = true })
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
