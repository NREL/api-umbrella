require_relative "../test_helper"

class Test::Proxy::TestTransferEncoding < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_response_empty
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/10", http_options)
    assert_response_code(200, response)
    assert_nil(response.headers["transfer-encoding"])
  end

  def test_response_chunked
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-header-value/", http_options.deep_merge({
      :params => {
        "header" => "Transfer-Encoding",
        "header_value" => "chunked",
      },
    }))
    assert_response_code(200, response)
    assert_equal("chunked", response.headers["transfer-encoding"])
  end

  def test_request_empty
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_nil(data["headers"]["transfer-encoding"])
  end

  def test_request_chunked
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Transfer-Encoding" => "chunked",
      },
      :body => Faker::Lorem.characters(:number => 10000),
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("chunked", data["headers"]["transfer-encoding"])
  end

  # As of TrafficServier 9, any Transfer-Encoding value in either the request
  # or response other than "chunked" results in an error:
  # https://github.com/apache/trafficserver/pull/7694
  #
  # In reviewing our production data, we haven't observed any other values, so
  # I think this is fine, but just documenting current behavior in case it
  # changes.
  def test_response_compress
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-header-value/", http_options.deep_merge({
      :params => {
        "header" => "Transfer-Encoding",
        "header_value" => "compress",
      },
    }))
    assert_response_code(502, response)
    assert_match("reset reason: protocol error", response.body)
  end

  def test_response_deflate
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-header-value/", http_options.deep_merge({
      :params => {
        "header" => "Transfer-Encoding",
        "header_value" => "deflate",
      },
    }))
    assert_response_code(502, response)
    assert_match("reset reason: protocol error", response.body)
  end

  def test_response_gzip
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-header-value/", http_options.deep_merge({
      :params => {
        "header" => "Transfer-Encoding",
        "header_value" => "gzip",
      },
    }))
    assert_response_code(502, response)
    assert_match("reset reason: protocol error", response.body)
  end

  def test_response_multi
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-header-value/", http_options.deep_merge({
      :params => {
        "header" => "Transfer-Encoding",
        "header_value" => "gzip, chunked",
      },
    }))
    assert_response_code(502, response)
    assert_match("reset reason: protocol error", response.body)
  end

  def test_response_unknown
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-header-value/", http_options.deep_merge({
      :params => {
        "header" => "Transfer-Encoding",
        "header_value" => "test123",
      },
    }))
    assert_response_code(502, response)
    assert_match("reset reason: protocol error", response.body)
  end

  def test_request_compress
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Transfer-Encoding" => "compress",
      },
      :body => "foobar",
    }))
    assert_response_code(501, response)
    assert_match("Not Implemented", response.body)
  end

  def test_request_deflate
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Transfer-Encoding" => "deflate",
      },
      :body => "foobar",
    }))
    assert_response_code(501, response)
    assert_match("Not Implemented", response.body)
  end

  def test_request_gzip
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Transfer-Encoding" => "gzip",
      },
      :body => "foobar",
    }))
    assert_response_code(501, response)
    assert_match("Not Implemented", response.body)
  end

  def test_request_multi
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Transfer-Encoding" => "gzip, chunked",
      },
      :body => "foobar",
    }))
    assert_response_code(501, response)
    assert_match("Not Implemented", response.body)
  end

  def test_request_unknown
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Transfer-Encoding" => "test123",
      },
      :body => "foobar",
    }))
    assert_response_code(501, response)
    assert_match("Not Implemented", response.body)
  end
end
