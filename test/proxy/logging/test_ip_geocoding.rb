require_relative "../../test_helper"

class Test::Proxy::Logging::TestIpGeocoding < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging

  def setup
    super
    setup_server
  end

  def test_nginx_geoip_config
    nginx_config_path = File.join($config.fetch("root_dir"), "etc/nginx/router.conf")
    nginx_config = File.read(nginx_config_path)
    assert_match("geoip2", nginx_config)
  end

  def test_does_not_run_auto_update_process
    processes = api_umbrella_process.processes
    assert_match(%r{^\[- --- ---\] *geoip-auto-updater *\(service not activated\)$}, processes)
  end

  def test_ipv4_address
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "216.160.83.56",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "216.160.83.56",
      :country => "US",
      :region => "WA",
      :city => "Milton",
      :lat => 47.2513,
      :lon => -122.3149,
    })
  end

  def test_ipv6_address
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "2001:0480:0014:11d8:3bb8:a4da:cb6e:68f8",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "2001:480:14:11d8:3bb8:a4da:cb6e:68f8",
      :country => "US",
      :region => "CA",
      :city => "San Diego",
      :lat => 32.7203,
      :lon => -117.1552,
    })
  end

  def test_ipv4_mapped_ipv6_address
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "0:0:0:0:0:ffff:d8a0:5338",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "::ffff:216.160.83.56",
      :country => "US",
      :region => "WA",
      :city => "Milton",
      :lat => 47.2513,
      :lon => -122.3149,
    })
  end

  def test_country_city_no_region
    override_config({
      "geoip" => {
        "db_path" => File.join(API_UMBRELLA_SRC_ROOT, "test/support/geoip/GeoIP2-City-Test.mmdb"),
      },
    }) do
      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
        :headers => {
          "X-Forwarded-For" => "214.0.0.0",
        },
      }))
      assert_response_code(200, response)

      record = wait_for_log(response)[:hit_source]
      assert_geocode(record, {
        :ip => "214.0.0.0",
        :country => "SG",
        :region => nil,
        :city => "Singapore",
        :lat => 1.336,
        :lon => 103.7716,
      })
    end
  end

  def test_country_no_region_city
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "67.43.156.0",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "67.43.156.0",
      :country => "BT",
      :region => nil,
      :city => nil,
      :lat => 27.5,
      :lon => 90.5,
    })
  end

  def test_no_country_region_city
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "127.0.0.1",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "127.0.0.1",
      :country => nil,
      :region => nil,
      :city => nil,
      :lat => nil,
      :lon => nil,
    })
  end

  def test_city_accent_chars
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "89.160.20.112",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "89.160.20.112",
      :country => "SE",
      :region => "E",
      :city => "Linköping",
      :lat => 58.4167,
      :lon => 15.6167,
    })
  end

  def test_custom_country_asia
    override_config({
      "geoip" => {
        "db_path" => File.join(API_UMBRELLA_SRC_ROOT, "test/support/geoip/custom.mmdb"),
      },
    }) do
      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
        :headers => {
          "X-Forwarded-For" => "1.0.0.1",
        },
      }))
      assert_response_code(200, response)

      record = wait_for_log(response)[:hit_source]
      assert_geocode(record, {
        :ip => "1.0.0.1",
        :country => "AP",
        :region => nil,
        :city => nil,
        :lat => 35.0,
        :lon => 105.0,
      })
    end
  end

  def test_custom_country_europe
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "2a02:d502:ff97::8888",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "2a02:d502:ff97::8888",
      :country => "EU",
      :region => nil,
      :city => nil,
      :lat => 48.69096,
      :lon => 9.14062,
    })
  end

  def test_custom_country_anonymous_proxy
    override_config({
      "geoip" => {
        "db_path" => File.join(API_UMBRELLA_SRC_ROOT, "test/support/geoip/GeoIP2-Country-Test.mmdb"),
      },
    }) do
      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
        :headers => {
          "X-Forwarded-For" => "::212.47.235.81",
        },
      }))
      assert_response_code(200, response)

      record = wait_for_log(response)[:hit_source]
      assert_geocode(record, {
        :ip => "::212.47.235.81",
        :country => "A1",
        :region => nil,
        :city => nil,
        :lat => nil,
        :lon => nil,
      })
    end
  end

  def test_custom_country_satellite
    override_config({
      "geoip" => {
        "db_path" => File.join(API_UMBRELLA_SRC_ROOT, "test/support/geoip/GeoIP2-Country-Test.mmdb"),
      },
    }) do
      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
        :headers => {
          "X-Forwarded-For" => "212.47.235.82",
        },
      }))
      assert_response_code(200, response)

      record = wait_for_log(response)[:hit_source]
      assert_geocode(record, {
        :ip => "212.47.235.82",
        :country => "A2",
        :region => nil,
        :city => nil,
        :lat => nil,
        :lon => nil,
      })
    end
  end

  def test_unknown_ip_not_in_db
    override_config({
      "geoip" => {
        "db_path" => File.join(API_UMBRELLA_SRC_ROOT, "test/support/geoip/custom.mmdb"),
      },
    }) do
      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
        :headers => {
          "X-Forwarded-For" => "9.0.0.1",
        },
      }))
      assert_response_code(200, response)

      record = wait_for_log(response)[:hit_source]
      assert_geocode(record, {
        :ip => "9.0.0.1",
        :country => nil,
        :region => nil,
        :city => nil,
        :lat => nil,
        :lon => nil,
      })
    end
  end

  # Since this table involves a "point" type column, ensure some of the SQL
  # triggers doing comparisons on changes work as expected. See:
  # https://www.mail-archive.com/pgsql-general@postgresql.org/msg198563.html
  # https://www.mail-archive.com/pgsql-general@postgresql.org/msg198866.html
  def test_cache_upsert_timestamp_tracking
    AnalyticsCity.connection.execute("INSERT INTO analytics_cities(country, region, city, location) VALUES('US', 'CO', #{AnalyticsCity.connection.quote(unique_test_id)}, point(1, 2)) ON CONFLICT (country, region, city) DO UPDATE SET location = EXCLUDED.location")
    city = AnalyticsCity.find_by!(:country => "US", :region => "CO", :city => unique_test_id)
    orig_created_at = city.created_at
    prev_updated_at = city.updated_at
    assert_equal(prev_updated_at.iso8601(10), city.created_at.iso8601(10))

    # Ensure a change triggers updated_at to change.
    AnalyticsCity.connection.execute("INSERT INTO analytics_cities(country, region, city, location) VALUES('US', 'CO', #{AnalyticsCity.connection.quote(unique_test_id)}, point(1, 3)) ON CONFLICT (country, region, city) DO UPDATE SET location = EXCLUDED.location")
    city.reload
    assert_equal(orig_created_at.iso8601(10), city.created_at.iso8601(10))
    refute_equal(prev_updated_at.iso8601(10), city.updated_at.iso8601(10))
    prev_updated_at = city.updated_at

    # If an update is performed without actually changing the values, then
    # updated_at should remain the same.
    AnalyticsCity.connection.execute("INSERT INTO analytics_cities(country, region, city, location) VALUES('US', 'CO', #{AnalyticsCity.connection.quote(unique_test_id)}, point(1, 3)) ON CONFLICT (country, region, city) DO UPDATE SET location = EXCLUDED.location")
    city.reload
    assert_equal(orig_created_at.iso8601(10), city.created_at.iso8601(10))
    assert_equal(prev_updated_at.iso8601(10), city.updated_at.iso8601(10))
    prev_updated_at = city.updated_at

    # Another change test.
    AnalyticsCity.connection.execute("INSERT INTO analytics_cities(country, region, city, location) VALUES('US', 'CO', #{AnalyticsCity.connection.quote(unique_test_id)}, point(1, 4)) ON CONFLICT (country, region, city) DO UPDATE SET location = EXCLUDED.location")
    city.reload
    assert_equal(orig_created_at.iso8601(10), city.created_at.iso8601(10))
    refute_equal(prev_updated_at.iso8601(10), city.updated_at.iso8601(10))
  end
end
