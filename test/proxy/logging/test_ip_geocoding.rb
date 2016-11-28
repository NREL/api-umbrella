require_relative "../../test_helper"

class Test::Proxy::Logging::TestIpGeocoding < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    setup_server
  end

  def test_ipv4_address
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "X-Forwarded-For" => "8.8.8.8",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_geocode(record, {
      :ip => "8.8.8.8",
      :country => "US",
      :region => "CA",
      :city => "Mountain View",
      :lat => 37.386,
      :lon => -122.0838,
    })
  end

  def test_ipv6_address
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "X-Forwarded-For" => "2001:4860:4860::8888",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(unique_test_id)[:hit_source]
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
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "X-Forwarded-For" => "0:0:0:0:0:ffff:808:808",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_geocode(record, {
      :ip => "::ffff:8.8.8.8",
      :country => "US",
      :region => "CA",
      :city => "Mountain View",
      :lat => 37.386,
      :lon => -122.0838,
    })
  end

  def test_country_city_no_region
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "X-Forwarded-For" => "104.250.168.24",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(unique_test_id)[:hit_source]
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
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "X-Forwarded-For" => "182.50.152.193",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_geocode(record, {
      :ip => "182.50.152.193",
      :country => "SG",
      :region => nil,
      :city => nil,
      :lat => 1.3667,
      :lon => 103.8,
    })
  end

  def test_city_accent_chars
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :params => {
        :unique_query_id => unique_test_id,
      },
      :headers => {
        "X-Forwarded-For" => "191.102.110.22",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(unique_test_id)[:hit_source]
    assert_geocode(record, {
      :ip => "191.102.110.22",
      :country => "CO",
      :region => "34",
      :city => "Bogotá",
      :lat => 4.6492,
      :lon => -74.0628,
    })
  end

  private

  def assert_geocode(record, options)
    assert_geocode_log(record, options)
    assert_geocode_cache(record, options)
  end

  def assert_geocode_log(record, options)
    assert_equal(options[:ip], record["request_ip"])
    assert_equal(options[:country], record["request_ip_country"])
    assert_equal(options[:region], record["request_ip_region"])
    assert_equal(options[:city], record["request_ip_city"])
    assert_equal(["lat", "lon"].sort, record["request_ip_location"].keys.sort)
    assert_in_delta(options[:lat], record["request_ip_location"]["lat"], 0.02)
    assert_in_delta(options[:lon], record["request_ip_location"]["lon"], 0.02)
  end

  def assert_geocode_cache(record, options)
    id = Digest::SHA256.hexdigest("#{options[:country]}-#{options[:region]}-#{options[:city]}")
    locations = LogCityLocation.where(:_id => id).all
    assert_equal(1, locations.length)

    location = locations[0].attributes
    updated_at = location.delete("updated_at")
    coordinates = location["location"].delete("coordinates")

    assert_kind_of(Time, updated_at)
    assert_equal(2, coordinates.length)
    assert_in_delta(options[:lon], coordinates[0], 0.02)
    assert_in_delta(options[:lat], coordinates[1], 0.02)
    assert_equal({
      "_id" => id,
      "country" => options[:country],
      "region" => options[:region],
      "city" => options[:city],
      "location" => {
        "type" => "Point",
      },
    }.compact, location)
  end
end
