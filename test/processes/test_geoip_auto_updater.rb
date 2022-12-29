require_relative "../test_helper"

class Test::Processes::TestGeoipAutoUpdater < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server

    @geoip_path = File.join($config.fetch("db_dir"), "geoip/GeoLite2-City.mmdb")

    once_per_class_setup do
      override_config_set({
        "geoip" => {
          "db_update_frequency" => 1,
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_checks_for_updates_skipping_recent_files
    log_tail = LogTail.new("geoip-auto-updater/current")
    nginx_log_tail = LogTail.new("nginx/current")

    FileUtils.touch(@geoip_path)

    log = log_tail.read_until(/Checking for geoip database updates.*Checking for geoip database updates/m)
    assert_match(%r{\[notice\].*Checking for geoip database updates}, log)
    assert_match(%r{\[notice\].*GeoLite2-City.mmdb recently updated \(\d+s ago\) - skipping}, log)

    nginx_log = nginx_log_tail.read
    refute_match("reconfiguring", nginx_log)
  end

  def test_downloads_but_keeps_existing_db_if_same
    log_tail = LogTail.new("geoip-auto-updater/current")
    nginx_log_tail = LogTail.new("nginx/current")

    FileUtils.touch(@geoip_path, :mtime => Time.now.utc - 2.days)

    log = log_tail.read_until(/Checking for geoip database updates.*Downloading new file.*Checking for geoip database updates/m, :timeout => 30)
    assert_match(%r{\[notice\].*Checking for geoip database updates}, log)
    assert_match(%r{\[notice\].*Downloading new file}, log)
    assert_match(%r{\[notice\].*GeoLite2-City.mmdb is already up to date \(checksum: \w{64}\)}, log)

    nginx_log = nginx_log_tail.read
    refute_match("reconfiguring", nginx_log)
  end

  def test_reloads_nginx_when_new_db_installed
    log_tail = LogTail.new("geoip-auto-updater/current")
    nginx_log_tail = LogTail.new("nginx/current")

    File.open(@geoip_path, "a") { |f| f.puts("\n") }
    FileUtils.touch(@geoip_path, :mtime => Time.now.utc - 2.days)

    log = log_tail.read_until(/Checking for geoip database updates.*Installed new geoip database.*starting geoip-auto-updater.*Checking for geoip database updates/m, :timeout => 30)
    assert_match(%r{\[notice\].*Checking for geoip database updates}, log)
    assert_match(%r{\[notice\].*Downloading new file}, log)
    assert_match(%r{\[notice\].*Installed new geoip database \(.*GeoLite2-City.mmdb\)}, log)
    assert_match(%r{\[notice\].*signal 15 \(SIGTERM\) received}, log)
    assert_match(%r{\[notice\].*Reloaded api-umbrella}, log)
    assert_match(%r{starting geoip-auto-updater}, log)

    nginx_log = nginx_log_tail.read_until("gracefully shutting down")
    assert_match(%r{\[notice\].*signal 1 \(SIGHUP\) received}, nginx_log)
    assert_match(%r{\[notice\].*reconfiguring}, nginx_log)
    assert_match(%r{\[notice\].*start worker processes}, nginx_log)
    assert_match(%r{\[notice\].*gracefully shutting down}, nginx_log)
  end
end
