require_relative "../../test_helper"

# Normalize the Accept-Encoding header to maximize caching:
# https://docs.trafficserver.apache.org/en/5.3.x/reference/configuration/records.config.en.html#proxy-config-http-normalize-ae-gzip
class Test::Proxy::RequestRewriting::TestAcceptEncodingNormalization < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_keeps_gzip
    assert_accept_encoding_received("gzip", "gzip")
  end

  def test_normalizes_containing_gzip_to_just_gzip
    assert_accept_encoding_received("gzip", "gzip, deflate, compress")
  end

  def test_removes_non_gzip
    assert_accept_encoding_received(nil, "deflate, compress")
  end

  def test_removes_non_gzip_containing_gzip_text
    assert_accept_encoding_received(nil, "gzipp")
  end

  def test_removes_gzip_with_quality_0_integer
    assert_accept_encoding_received(nil, "gzip;q=0")
  end

  def test_removes_gzip_with_quality_0_float
    assert_accept_encoding_received(nil, "gzip;q=0.00")
  end

  def test_normalizes_gzip_with_quality
    assert_accept_encoding_received("gzip", "gzip;q=0.01")
  end

  def test_normalizes_gzip_with_quality_and_others
    assert_accept_encoding_received("gzip", "identity; q=1.0, gzip;q=0.5, *;q=0")
  end

  def test_removes_empty_string
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge(empty_http_header_options("Accept-Encoding")))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_nil(data["headers"]["accept-encoding"])
  end

  private

  def assert_accept_encoding_received(expected_value_received, value_to_send)
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :accept_encoding => value_to_send,
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    if(expected_value_received.nil?)
      assert_nil(data["headers"]["accept-encoding"])
    else
      assert_equal(expected_value_received, data["headers"]["accept-encoding"])
    end
  end
end
