local dir = require "pl.dir"
local escape_regex = require "api-umbrella.utils.escape_regex"
local etlua_render = require("etlua").render
local file = require "pl.file"
local geoip_download_if_missing_or_old = require("api-umbrella.utils.geoip").download_if_missing_or_old
local invert_table = require "api-umbrella.utils.invert_table"
local path = require "pl.path"
local read_config = require "api-umbrella.cli.read_config"
local shell_blocking_capture_combined = require("shell-games").capture_combined
local stat = require "posix.sys.stat"
local tablex = require "pl.tablex"
local unistd = require "posix.unistd"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local chmod = stat.chmod
local chown = unistd.chown
local file_write = file.write
local path_basename = path.basename
local path_exists = path.exists
local path_join = path.join

local config

local function permission_check()
  local effective_uid = unistd.geteuid()
  if config["user"] then
    if effective_uid ~= 0 then
      print("Must be started with super-user privileges to change user to '" .. config["user"] .. "'")
      os.exit(1)
    end

    local result, err = shell_blocking_capture_combined({ "getent", "passwd", config["user"] })
    if result["status"] == 2 and result["output"] == "" then
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

    local result, err = shell_blocking_capture_combined({ "getent", "group", config["group"] })
    if result["status"] == 2 and result["output"] == "" then
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
    path_join(config["run_dir"], "envoy"),
  }

  for _, directory in ipairs(dirs) do
    dir.makepath(directory)
  end

  local cds_path = path_join(config["run_dir"], "envoy/cds.json")
  if not path_exists(cds_path) then
    file_write(cds_path, "{}")
  end
  local lds_path = path_join(config["run_dir"], "envoy/lds.json")
  if not path_exists(lds_path) then
    file_write(lds_path, "{}")
  end
  local rds_path = path_join(config["run_dir"], "envoy/rds.json")
  if not path_exists(rds_path) then
    file_write(rds_path, "{}")
  end
end

local function generate_cert(subject, key_filename, crt_filename)
  local ssl_dir = path_join(config["etc_dir"], "ssl");
  local ssl_key_path = path_join(ssl_dir, key_filename);
  local ssl_crt_path = path_join(ssl_dir, crt_filename);

  if not path_exists(ssl_key_path) or not path_exists(ssl_crt_path) then
    dir.makepath(ssl_dir)
    local _, err = shell_blocking_capture_combined({ "openssl", "req", "-new", "-newkey", "rsa:2048", "-days", "3650", "-nodes", "-x509", "-subj", subject, "-keyout", ssl_key_path, "-out", ssl_crt_path })
    if err then
      print(err)
      os.exit(1)
    end
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
    generate_cert("/O=API Umbrella/CN=apiumbrella.example.com", "self_signed.key", "self_signed.crt")
  end
end

local function generate_auto_ssl_fallback_cert()
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
    generate_cert("/CN=sni-support-required-for-valid-ssl", "auto_ssl_fallback.key", "auto_ssl_fallback.crt")
  end
end


local function ensure_geoip_db()
  local _, err = geoip_download_if_missing_or_old(config)
  if err then
    ngx.log(ngx.ERR, "geoip database download failed: ", err)
    config["geoip"]["_enabled"] = false
  else
    config["geoip"]["_enabled"] = true
  end
end

local function set_template_permissions(file_path, install_filename)
  if config["group"] then
    chown(file_path, nil, config["group"])
  end

  if install_filename == "rc.log" or install_filename == "rc.main" or install_filename == "rc.perp" then
    chmod(file_path, tonumber("0750", 8))
  else
    chmod(file_path, tonumber("0640", 8))
  end
end

local function write_templates()
  local created_dirs = {}
  local template_root = path_join(config["_src_root_dir"], "templates/etc")
  for root, _, files in dir.walk(template_root) do
    for _, dir_path in ipairs(files) do
      local template_path = path_join(root, dir_path)

      local process = true
      local is_hidden = (string.sub(dir_path, 1, 1) == ".")
      if is_hidden then
        process = false
      end

      local is_dev_file = (string.find(template_path, "dev-env", 1, true) ~= nil)
      if is_dev_file and config["app_env"] ~= "development" then
        process = false
      end

      local is_test_file = (string.find(template_path, "test-env", 1, true) ~= nil)
      if is_test_file and config["app_env"] ~= "test" then
        process = false
      end

      if process then
        local path_parts, path_match_err = ngx.re.match(template_path, [[^]] .. escape_regex(template_root .. "/") .. [[((.+?)([^/]+?))(?:\.(etlua))?$]], "jo")
        if not path_parts then
          print("path not matched: " .. template_path)
          os.exit(1)
        elseif path_match_err then
          print("regex error: " .. path_match_err)
          os.exit(1)
        else
          local install_dir = path_join(config["etc_dir"], path_parts[2])
          local install_path = path_join(config["etc_dir"], path_parts[1])
          local filename = path_parts[3]
          local template_ext = path_parts[4]

          local content = file.read(template_path, true)

          if template_ext == "etlua" then
            local render_ok, render_err
            render_ok, content, render_err = xpcall(etlua_render, xpcall_error_handler, content, { config = config })
            if not render_ok or render_err then
              print("template compile error in " .. template_path ..": " .. (render_err or content))
              os.exit(1)
            end
          end

          -- Only write the file if it differs from the existing file. This helps
          -- prevents some processes, like Trafficserver, from thinking there are
          -- config file updates to process on reloads if the file timestamps
          -- change (even if there aren't actually any changes).
          local _, existing_content = xpcall(file.read, xpcall_error_handler, install_path, true)
          if content ~= existing_content then
            -- Write the config file in an atomic fashion (by writing to a temp
            -- file and then moving into place), so that during reloads the
            -- processes never read a half-written file.
            if not created_dirs[install_dir] then
              dir.makepath(install_dir)
              created_dirs[install_dir] = true
            end

            local temp_filename = "." .. filename .. ".tmp"
            local temp_path = path_join(install_dir, temp_filename)
            local _, write_err = file.write(temp_path, content)
            if write_err then
              print("write failed: ", write_err)
              os.exit(1)
            end
            set_template_permissions(temp_path, filename)

            local rename_ok, rename_err = os.rename(temp_path, install_path)
            if not rename_ok then
              print("Move file failed: " .. rename_err)
              os.exit(1)
            end
          else
            set_template_permissions(install_path, filename)
          end
        end
      end
    end
  end
end

local function write_static_site_key()
  local file_paths = {
    path_join(config["static_site"]["build_dir"], "contact/index.html"),
    path_join(config["static_site"]["build_dir"], "signup/index.html"),
  }
  for _, file_path in ipairs(file_paths) do
    if not path_exists(file_path) then
      print("File does not exist: " .. file_path)
      os.exit(1)
    end

    local content = file.read(file_path)
    local new_content, replacements = string.gsub(content, "apiKey: '.-'", "apiKey: '" .. config["static_site"]["api_key"] .. "'")
    if replacements > 0 then
      local _, write_err = file.write(file_path, new_content)
      if write_err then
        print("write failed: ", write_err)
        os.exit(1)
      end
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
    chown(path_join(config["db_dir"], "geoip"), nil, group)
    chown(path_join(config["etc_dir"], "elasticsearch"), nil, group)
    chown(path_join(config["etc_dir"], "nginx"), nil, group)
    chown(path_join(config["etc_dir"], "perp"), nil, group)
    chown(path_join(config["etc_dir"], "trafficserver"), nil, group)

    if config["app_env"] == "test" then
      chown(path_join(config["etc_dir"], "test-env"), nil, group)
      chown(path_join(config["etc_dir"], "test-env/mongo-orchestration"), nil, group)
      chown(path_join(config["etc_dir"], "test-env/nginx"), nil, group)
      chown(path_join(config["etc_dir"], "test-env/unbound"), nil, group)
    end
  end

  local service_dirs = dir.getdirectories(path_join(config["etc_dir"], "perp"))
  for _, service_dir in ipairs(service_dirs) do
    chmod(service_dir, tonumber("0750", 8))
    if config["group"] then
      chown(service_dir, nil, config["group"])
    end
  end
end

local function activate_services()
  local available_services = dir.getdirectories(path_join(config["_src_root_dir"], "templates/etc/perp"))
  tablex.transform(path_basename, available_services)
  available_services = invert_table(available_services)

  local active_services = {}
  if config["_service_elasticsearch_aws_signing_proxy_enabled?"] then
    active_services["elasticsearch-aws-signing-proxy"] = 1
  end
  if config["_service_router_enabled?"] then
    if config["geoip"]["_enabled"] then
      active_services["geoip-auto-updater"] = 1
    end
    active_services["envoy"] = 1
    active_services["nginx"] = 1
    active_services["rsyslog"] = 1
    active_services["trafficserver"] = 1
  end
  if config["_service_auto_ssl_enabled?"] then
    active_services["nginx-auto-ssl"] = 1
  end
  if config["_service_web_enabled?"] then
    active_services["nginx-web-app"] = 1
  end
  if config["app_env"] == "development" then
    active_services["dev-env-ember-server"] = 1
    active_services["dev-env-example-website-hugo"] = 1
  end
  if config["app_env"] == "test" then
    active_services["test-env-glauth"] = 1
    active_services["test-env-mailhog"] = 1
    active_services["test-env-nginx"] = 1
    active_services["test-env-unbound"] = 1
  end

  -- Loop over the perp controlled services and set the sticky permission bit
  -- for any services that are supposed to be active (this sticky bit is how
  -- perp determines which services to run).
  local installed_service_dirs = dir.getdirectories(path_join(config["etc_dir"], "perp"))
  for _, service_dir in ipairs(installed_service_dirs) do
    local service_name = path_basename(service_dir)

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

      local service_log_dir = path_join(config["log_dir"], service_log_name)
      dir.makepath(service_log_dir)
      local _, log_chmod_err = shell_blocking_capture_combined({ "chmod", "0755", service_log_dir })
      if log_chmod_err then
        print("chmod failed: ", log_chmod_err)
        os.exit(1)
      end
      if config["user"] and config["group"] then
        local _, log_chown_err = shell_blocking_capture_combined({ "chown", config["user"] .. ":" .. config["group"], service_log_dir })
        if log_chown_err then
          print("chown failed: ", log_chown_err)
          os.exit(1)
        end
      end
    end

    -- Set the sticky bit for any active services.
    if is_active then
      chmod(service_dir, tonumber("1750", 8))

      local log_dir = path_join(config["log_dir"], service_name)
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
  generate_auto_ssl_fallback_cert()
  ensure_geoip_db()
  write_templates()
  write_static_site_key()
  set_permissions()
  activate_services()

  return config
end
