require_relative "../../test_helper"

class Test::Proxy::Logging::TestIpGeocoding < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    super
    setup_server

    assert($config["geoip"]["maxmind_license_key"], "MAXMIND_LICENSE_KEY environment variable must be set with valid license for geoip tests to run")
  end

  def test_nginx_geoip_config
    nginx_config_path = File.join($config.fetch("root_dir"), "etc/nginx/router.conf")
    nginx_config = File.read(nginx_config_path)
    assert_match("geoip2", nginx_config)
  end

  def test_runs_auto_update_process
    processes = api_umbrella_process.processes
    assert_match(%r{^\[\+ \+\+\+ \+\+\+\] *geoip-auto-updater *uptime: \d+\w/\d+\w *pids: \d+/\d+$}, processes)
  end

  def test_ipv4_address
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "52.52.118.192",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "52.52.118.192",
      :country => "US",
      :region => "CA",
      :city => "San Jose",
      :lat => 37.1835,
      :lon => -121.7714,
    })
  end

  def test_ipv6_address
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "2001:4860:4860::8888",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "2001:4860:4860::8888",
      :country => "US",
      :region => nil,
      :city => nil,
      :lat => 37.751,
      :lon => -97.822,
    })
  end

  def test_ipv4_mapped_ipv6_address
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "0:0:0:0:0:ffff:3434:76c0",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "::ffff:52.52.118.192",
      :country => "US",
      :region => "CA",
      :city => "San Jose",
      :lat => 37.1835,
      :lon => -121.7714,
    })
  end

  def test_country_city_no_region
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "102.38.240.0",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "102.38.240.0",
      :country => "MC",
      :region => nil,
      :city => "Monte Carlo",
      :lat => 43.7312,
      :lon => 7.4138,
    })
  end

  def test_country_no_region_city
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "1.1.0.0",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "1.1.0.0",
      :country => "CN",
      :region => nil,
      :city => nil,
      :lat => 34.7732,
      :lon => 113.722,
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
        "X-Forwarded-For" => "184.148.224.214",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "184.148.224.214",
      :country => "CA",
      :region => "QC",
      :city => "Trois-Rivières",
      :lat => 46.4176,
      :lon => -72.6372,
    })
  end

  def test_custom_country_asia
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "15.211.169.0",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "15.211.169.0",
      :country => "AP",
      :region => nil,
      :city => nil,
      :lat => 35.0,
      :lon => 105.0,
    })
  end

  def test_custom_country_europe
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "77.111.247.0",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "77.111.247.0",
      :country => "EU",
      :region => nil,
      :city => nil,
      :lat => 47.0,
      :lon => 8.0,
    })
  end

  def test_custom_country_anonymous_proxy
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "23.151.232.4",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "23.151.232.4",
      :country => "A1",
      :region => nil,
      :city => nil,
      :lat => nil,
      :lon => nil,
    })
  end

  def test_custom_country_satellite
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "196.201.135.0",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "196.201.135.0",
      :country => "A2",
      :region => nil,
      :city => nil,
      :lat => nil,
      :lon => nil,
    })
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

  private

  def assert_geocode(record, options)
    assert_geocode_log(record, options)
    if !options.fetch(:lat).nil? || !options.fetch(:lon).nil?
      assert_geocode_cache(record, options)
    end
  end

  def assert_geocode_log(record, options)
    assert_equal(options.fetch(:ip), record.fetch("request_ip"))
    if(options.fetch(:country).nil?)
      assert_nil(record["request_ip_country"])
      refute(record.key?("request_ip_country"))
    else
      assert_equal(options.fetch(:country), record.fetch("request_ip_country"))
    end
    if(options.fetch(:region).nil?)
      assert_nil(record["request_ip_region"])
      refute(record.key?("request_ip_region"))
    else
      assert_equal(options.fetch(:region), record.fetch("request_ip_region"))
    end
    if(options.fetch(:city).nil?)
      assert_nil(record["request_ip_city"])
      refute(record.key?("request_ip_city"))
    else
      assert_equal(options.fetch(:city), record.fetch("request_ip_city"))
    end
  end

  def assert_geocode_cache(record, options)
    cities = AnalyticsCity.where(:country => options.fetch(:country), :region => options.fetch(:region), :city => options.fetch(:city)).all
    assert_equal(1, cities.length)

    city = cities.first
    assert_equal([
      "id",
      "country",
      "region",
      "city",
      "location",
      "created_at",
      "updated_at",
    ].sort, city.attributes.keys.sort)

    assert_kind_of(Numeric, city.id)
    assert_equal(options.fetch(:country), city.country)
    if(options.fetch(:region).nil?)
      assert_nil(city.region)
    else
      assert_equal(options.fetch(:region), city.region)
    end
    if(options.fetch(:city).nil?)
      assert_nil(city.city)
    else
      assert_equal(options.fetch(:city), city.city)
    end
    assert_in_delta(options.fetch(:lon), city.location.x, 0.02)
    assert_in_delta(options.fetch(:lat), city.location.y, 0.02)
    assert_kind_of(Time, city.created_at)
    assert_kind_of(Time, city.updated_at)
  end
end
