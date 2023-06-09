local checksum_file_sha256 = require("api-umbrella.utils.checksum_file").sha256
local dirname = require("posix.libgen").dirname
local mkdir_p = require "api-umbrella.utils.mkdir_p"
local mkdtemp = require("posix.stdlib").mkdtemp
local path_exists = require "api-umbrella.utils.path_exists"
local path_join = require "api-umbrella.utils.path_join"
local shell_blocking_capture_combined = require("shell-games").capture_combined
local stat = require("posix.sys.stat").stat

local escape_uri = ngx.escape_uri
local time = ngx.time

local _M = {}

local function perform_download(config, unzip_dir, download_path)
  -- Download file
  ngx.log(ngx.NOTICE, "Downloading new file (" .. download_path .. ")")
  local download_url = "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&suffix=tar.gz&license_key=" .. escape_uri(config["geoip"]["maxmind_license_key"])
  local _, curl_err = shell_blocking_capture_combined({ "curl", "--silent", "--show-error", "--fail", "--location", "--retry", "3", "--output", download_path, download_url })
  if curl_err then
    return false, curl_err
  end

  -- Decompress
  local _, tar_err = shell_blocking_capture_combined({ "tar", "-xof", download_path, "-C", unzip_dir, "--strip-components", "1" })
  if tar_err then
    return false, tar_err
  end

  -- Checksum current db file.
  local current_path = path_join(config["db_dir"], "geoip/GeoLite2-City.mmdb")
  local current_checksum
  if path_exists(current_path) then
    local current_checksum_err
    current_checksum, current_checksum_err = checksum_file_sha256(current_path)
    if current_checksum_err then
      return false, current_checksum_err
    end
  end

  -- Checksum new db file.
  local unzip_path = path_join(unzip_dir, "GeoLite2-City.mmdb")
  local unzip_checksum, unzip_checksum_err = checksum_file_sha256(unzip_path)
  if unzip_checksum_err then
    return false, unzip_checksum_err
  end

  -- If the new file is different, move it into place.
  if current_checksum == unzip_checksum then
    ngx.log(ngx.NOTICE, current_path .. " is already up to date (checksum: " .. current_checksum ..")")
  else
    local _, mkdir_err = mkdir_p(dirname(current_path))
    if mkdir_err then
      return false, mkdir_err
    end

    -- Use `mv` instead of `os.rename`, since `os.rename` does not support
    -- moving files if the tempdir is on a different partition than the install
    -- path.
    local _, move_err = shell_blocking_capture_combined({ "mv", unzip_path, current_path })
    if move_err then
      return false, move_err
    end
    ngx.log(ngx.NOTICE, "Installed new geoip database (" .. current_path .. ")")
  end

  -- Touch the file so we know we've checked it recently (even if we didn't
  -- replace it because the new file was identical to the current file).
  local _, touch_err = shell_blocking_capture_combined({ "touch", current_path })
  if touch_err then
    return false, touch_err
  end

  local status = "unchanged"
  if current_checksum ~= unzip_checksum then
    status = "changed"
  end

  return status
end

function _M.download(config)
  -- Ensure license key is present, since otherwise downloading won't work.
  if not config["geoip"]["maxmind_license_key"] then
    return false, "Can't download geoip database due to missing geoip.maxmind_license_key config"
  end

  -- Create temp directory for decompressing to.
  local unzip_dir, mkdtemp_err = mkdtemp(path_join(os.getenv("TMPDIR") or "/tmp", "api-umbrella-geoip-auto-updater.XXXXXX"))
  if mkdtemp_err then
    return false, mkdtemp_err
  end

  local download_path = unzip_dir .. ".tar.gz"
  local status, err = perform_download(config, unzip_dir, download_path)

  -- Cleanup temp directory and temp download file.
  local _, rm_err = shell_blocking_capture_combined({ "rm", "-rf", unzip_dir, download_path })
  if rm_err then
    return false, rm_err
  end

  return status, err
end

function _M.download_if_missing_or_old(config)
  -- Ensure license key is present, since otherwise downloading won't work.
  if not config["geoip"]["maxmind_license_key"] then
    return false, "Can't download geoip database due to missing geoip.maxmind_license_key config"
  end

  local city_db_path = path_join(config["db_dir"], "geoip/GeoLite2-City.mmdb")
  local download = false
  if not path_exists(city_db_path) then
    download = true
  else
    -- Check the age of the current file. Don't attempt to download if the
    -- current file has recently been updated.
    local city_db_stat = stat(city_db_path)
    local age = time() - city_db_stat.st_mtime
    if age < config["geoip"]["db_update_age"] then
      ngx.log(ngx.NOTICE, city_db_path .. " recently updated (" .. age .. "s ago) - skipping")
    else
      download = true
    end
  end

  if download then
    return _M.download(config)
  end
end

return _M
