require_relative "../../test_helper"

class Test::Proxy::Logging::TestIpGeocoding < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    super
    setup_server
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
      :lat => 37.3388,
      :lon => -121.8914,
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
      :lat => 37.3388,
      :lon => -121.8914,
    })
  end

  def test_country_city_no_region
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "104.250.168.24",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "104.250.168.24",
      :country => "MC",
      :region => nil,
      :city => "Monte-carlo",
      :lat => 43.7333,
      :lon => 7.4167,
    })
  end

  def test_country_no_region_city
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-For" => "67.43.156.1",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "67.43.156.1",
      :country => "A1",
      :region => nil,
      :city => nil,
      :lat => 0.0,
      :lon => 0.0,
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
      :city => "Trois-rivières",
      :lat => 46.316,
      :lon => -72.6833,
    })
  end

  private

  def assert_geocode(record, options)
    assert_geocode_log(record, options)
    assert_geocode_cache(record, options)
  end

  def assert_geocode_log(record, options)
    assert_equal(options.fetch(:ip), record.fetch("request_ip"))
    assert_equal(options.fetch(:country), record.fetch("request_ip_country"))
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
