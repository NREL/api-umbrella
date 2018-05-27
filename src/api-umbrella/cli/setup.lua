local dir = require "pl.dir"
local file = require "pl.file"
local invert_table = require "api-umbrella.utils.invert_table"
local lustache = require "lustache"
local mustache_unescape = require "api-umbrella.utils.mustache_unescape"
local path = require "pl.path"
local plutils = require "pl.utils"
local read_config = require "api-umbrella.cli.read_config"
local run_command = require "api-umbrella.utils.run_command"
local stat = require "posix.sys.stat"
local tablex = require "pl.tablex"
local unistd = require "posix.unistd"

local chmod = stat.chmod
local chown = unistd.chown

local config

local function permission_check()
  local effective_uid = unistd.geteuid()
  if config["user"] then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to change user to '" .. config["user"] .. "'")
      os.exit(1)
    end

    local status, output, err = run_command({ "getent", "passwd", config["user"] })
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

    local status, output, err = run_command({ "getent", "group", config["group"] })
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

  if effective_uid == 0 and config["app_env"] ~= "test" then
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
      local _, _, err = run_command({ "openssl", "req", "-new", "-newkey", "rsa:2048", "-days", "3650", "-nodes", "-x509", "-subj", "/O=API Umbrella/CN=apiumbrella.example.com", "-keyout", ssl_key_path, "-out", ssl_crt_path })
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
    chmod(city_db_path, tonumber("0640", 8))
    if config["group"] then
      chown(city_db_path, nil, config["group"])
    end
  end
end

local function write_templates()
  local template_root = path.join(config["_src_root_dir"], "templates/etc")
  for root, _, files in dir.walk(template_root) do
    for _, filename in ipairs(files) do
      local template_path = path.join(root, filename)

      local process = true
      local is_hidden = (string.find(filename, ".", 1, true) == 1)
      if is_hidden then
        process = false
      end

      local is_dev_file = (string.find(template_path, "dev-env") ~= nil)
      if is_dev_file and config["app_env"] ~= "development" then
        process = false
      end

      local is_test_file = (string.find(template_path, "test-env") ~= nil)
      if is_test_file and config["app_env"] ~= "test" then
        process = false
      end

      if process then
        local install_path = string.gsub(template_path, "^" .. plutils.escape(template_root .. "/"), "", 1)
        install_path = string.gsub(install_path, plutils.escape(".mustache") .. "$", "", 1)
        install_path = path.join(config["etc_dir"], install_path)

        local content = file.read(template_path, true)

        local _, extension = path.splitext(template_path)
        if extension == ".mustache" then
          content = lustache:render(mustache_unescape(content), config)
        end

        dir.makepath(path.dirname(install_path))
        file.write(install_path, content)
        if config["group"] then
          chown(install_path, nil, config["group"])
        end

        local install_filename = path.basename(install_path)
        if install_filename == "rc.log" or install_filename == "rc.main" or install_filename == "rc.perp" then
          chmod(install_path, tonumber("0750", 8))
        else
          chmod(install_path, tonumber("0640", 8))
        end
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
  chmod(config["tmp_dir"], tonumber("1777", 8))

  if config["user"] and config["group"] then
    local user = config["user"]
    local group = config["group"]
    chown(config["db_dir"], nil, group)
    chown(config["log_dir"], nil, group)
    chown(config["run_dir"], user, group)
    chown(config["tmp_dir"], user, group)
    chown(config["var_dir"], nil, group)
    chown(config["etc_dir"], nil, group)
    chown(path.join(config["db_dir"], "geoip"), nil, group)
    chown(path.join(config["etc_dir"], "elasticsearch"), nil, group)
    chown(path.join(config["etc_dir"], "nginx"), nil, group)
    chown(path.join(config["etc_dir"], "perp"), nil, group)
    chown(path.join(config["etc_dir"], "trafficserver"), nil, group)

    if config["app_env"] == "test" then
      chown(path.join(config["etc_dir"], "test-env"), nil, group)
      chown(path.join(config["etc_dir"], "test-env/mongo-orchestration"), nil, group)
      chown(path.join(config["etc_dir"], "test-env/nginx"), nil, group)
      chown(path.join(config["etc_dir"], "test-env/openldap"), nil, group)
      chown(path.join(config["etc_dir"], "test-env/unbound"), nil, group)
    end
  end

  local service_dirs = dir.getdirectories(path.join(config["etc_dir"], "perp"))
  for _, service_dir in ipairs(service_dirs) do
    chmod(service_dir, tonumber("0750", 8))
    if config["group"] then
      chown(service_dir, nil, config["group"])
    end
  end
end

local function activate_services()
  local available_services = dir.getdirectories(path.join(config["_src_root_dir"], "templates/etc/perp"))
  tablex.transform(path.basename, available_services)
  available_services = invert_table(available_services)

  local active_services = {}
  if config["_service_general_db_enabled?"] then
    active_services["mongod"] = 1
  end
  if config["_service_log_db_enabled?"] then
    active_services["elasticsearch"] = 1
  end
  if config["_service_router_enabled?"] then
    active_services["geoip-auto-updater"] = 1
    active_services["mora"] = 1
    active_services["nginx"] = 1
    active_services["nginx-reloader"] = 1
    active_services["rsyslog"] = 1
    active_services["trafficserver"] = 1
  end
  if config["_service_web_enabled?"] then
    active_services["web-delayed-job"] = 1
    active_services["web-puma"] = 1
  end
  if config["app_env"] == "development" then
    active_services["dev-env-ember-server"] = 1
  end
  if config["app_env"] == "test" then
    active_services["test-env-mailhog"] = 1
    active_services["test-env-mongo-orchestration"] = 1
    active_services["test-env-nginx"] = 1
    active_services["test-env-openldap"] = 1
    active_services["test-env-unbound"] = 1
  end

  -- Loop over the perp controlled services and set the sticky permission bit
  -- for any services that are supposed to be active (this sticky bit is how
  -- perp determines which services to run).
  local installed_service_dirs = dir.getdirectories(path.join(config["etc_dir"], "perp"))
  for _, service_dir in ipairs(installed_service_dirs) do
    local service_name = path.basename(service_dir)

    -- Disable any old services that might be installed, but are no longer
    -- present in templates/etc/perp.
    local is_active = false
    if available_services[service_name] and active_services[service_name] then
      is_active = true
    end

    -- Perp's hidden directories don't need the sticky bit.
    local is_hidden = (string.find(service_name, ".", 1, true) == 1)
    if is_hidden then
      is_active = false
    end

    -- Create the log directory for svlogd output for this service.
    if is_active or service_name == ".boot" then
      local service_log_name = service_name
      if service_name == ".boot" then
        service_log_name = "perpd"
      end

      local service_log_dir = path.join(config["log_dir"], service_log_name)
      dir.makepath(service_log_dir)
      local _, _, log_chmod_err = run_command({ "chmod", "0755", service_log_dir })
      if log_chmod_err then
        print("chmod failed: ", log_chmod_err)
        os.exit(1)
      end
      if config["user"] and config["group"] then
        local _, _, log_chown_err = run_command({ "chown", config["user"] .. ":" .. config["group"], service_log_dir })
        if log_chown_err then
          print("chown failed: ", log_chown_err)
          os.exit(1)
        end
      end

      -- Disable the svlogd script if we want all output to go to
      -- stdout/stderr.
      if config["log"]["destination"] == "console" then
        local _, _, err = run_command({ "chmod", "-x", service_dir .. "/rc.log" })
        if err then
          print("chmod failed: ", err)
          os.exit(1)
        end
      end
    end

    -- Set the sticky bit for any active services.
    if is_active then
      chmod(service_dir, tonumber("1750", 8))

      local log_dir = path.join(config["log_dir"], service_name)
      dir.makepath(log_dir)
      chmod(log_dir, tonumber("0750", 8))
      if config["user"] and config["group"] then
        chown(log_dir, config["user"], config["group"])
      end
    else
      chmod(service_dir, tonumber("0750", 8))
    end
  end
end

return function()
  config = read_config({ write = true })
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
