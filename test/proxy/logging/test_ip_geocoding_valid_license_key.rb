require_relative "../../test_helper"

class Test::Proxy::Logging::TestIpGeocodingValidLicenseKey < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  include Minitest::Hooks

  def setup
    super
    setup_server

    @@geoip_path = File.join($config.fetch("db_dir"), "geoip/GeoLite2-City.mmdb")

    once_per_class_setup do
      # Verify that before the download, the IP we want to test isn't in the
      # default test file, so that way we ensure the download actually took
      # effect.
      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
        :headers => {
          "X-Forwarded-For" => "2.2.3.0",
        },
      }))
      assert_response_code(200, response)
      record = wait_for_log(response)[:hit_source]
      assert_geocode(record, {
        :ip => "2.2.3.0",
        :country => nil,
        :region => nil,
        :city => nil,
        :lat => nil,
        :lon => nil,
      })

      FileUtils.rm_f(@@geoip_path)
      override_config_set({
        "geoip" => {
          "db_path" => @@geoip_path,
          "db_update_frequency" => 86400,
          "city_download_url" => "http://127.0.0.1:9444/geoip_download/GeoLite2-City.tar.gz",
          "maxmind_license_key" => "DUMMY_KEY",
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
    FileUtils.rm_f(@@geoip_path)
  end

  def test_runs_auto_update_process
    processes = api_umbrella_process.processes
    assert_match(%r{^\[\+ \+\+\+ \+\+\+\] *geoip-auto-updater *uptime: \d+\w/\d+\w *pids: \d+/\d+$}, processes)
  end

  def test_ipv4_address
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "2.2.3.0",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "2.2.3.0",
      :country => "GB",
      :region => "ENG",
      :city => "Boxford",
      :lat => 51.75,
      :lon => -1.25,
    })
  end
end
