require_relative "../../test_helper"

class Test::Proxy::Logging::TestIpGeocodingNoLicenseKey < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        "geoip" => {
          "maxmind_license_key" => nil,
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_no_nginx_geoip_config
    nginx_config_path = File.join($config.fetch("etc_dir"), "nginx/router.conf")
    nginx_config = File.read(nginx_config_path)
    refute_match("geoip2", nginx_config)
  end

  def test_runs_auto_update_process
    processes = api_umbrella_process.processes
    assert_match(%r{^\[- --- ---\] *geoip-auto-updater *\(service not activated\)$}, processes)
  end

  def test_logs_but_no_geoip
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "52.52.118.192",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("52.52.118.192", record.fetch("request_ip"))
    assert_nil(record["request_ip_country"])
    refute(record.key?("request_ip_country"))
    assert_nil(record["request_ip_region"])
    refute(record.key?("request_ip_region"))
    assert_nil(record["request_ip_city"])
    refute(record.key?("request_ip_city"))
  end
end
