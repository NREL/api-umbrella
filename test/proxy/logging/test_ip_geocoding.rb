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
        "X-Forwarded-For" => "178.203.88.46",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_geocode(record, {
      :ip => "178.203.88.46",
      :country => "DE",
      :region => "07",
      :city => "Düsseldorf",
      :lat => 51.216499,
      :lon => 6.783600,
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
    id = Digest::SHA256.hexdigest("#{options.fetch(:country)}-#{options.fetch(:region)}-#{options.fetch(:city)}")
    locations = LogCityLocation.where(:_id => id).all
    assert_equal(1, locations.length)

    location = locations[0].attributes
    updated_at = location.delete("updated_at")
    coordinates = location["location"].delete("coordinates")

    assert_kind_of(Time, updated_at)
    assert_equal(2, coordinates.length)
    assert_in_delta(options.fetch(:lon), coordinates[0], 0.02)
    assert_in_delta(options.fetch(:lat), coordinates[1], 0.02)
    assert_equal({
      "_id" => id,
      "country" => options.fetch(:country),
      "region" => options.fetch(:region),
      "city" => options.fetch(:city),
      "location" => {
        "type" => "Point",
      },
    }.compact, location)
  end
end
