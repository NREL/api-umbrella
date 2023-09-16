require_relative "../../test_helper"

class Test::Proxy::Logging::TestIpGeocodingValidLicenseKey < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  include Minitest::Hooks

  def setup
    super
    setup_server

    @@geoip_path = File.join($config.fetch("db_dir"), "geoip/GeoLite2-City.mmdb")
    assert(ENV.fetch("MAXMIND_LICENSE_KEY", nil), "MAXMIND_LICENSE_KEY environment variable must be set with valid license for geoip tests to run")

    once_per_class_setup do
      FileUtils.rm_f(@@geoip_path)
      override_config_set({
        "geoip" => {
          "db_path" => @@geoip_path,
          "db_update_frequency" => 86400,
          "maxmind_license_key" => ENV.fetch("MAXMIND_LICENSE_KEY"),
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
        "X-Forwarded-For" => "52.4.0.0",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "52.4.0.0",
      :country => "US",
      :region => "VA",
      :city => "Ashburn",
      :lat => 39.0469,
      :lon => -77.4903,
    })
  end
end
