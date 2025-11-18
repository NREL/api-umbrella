require_relative "../../test_helper"

class Test::Proxy::Gzip::TestBackendReturnsNonGzipped < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_gzips_response_when_content_length_exceeds_1000
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/1000?#{unique_test_id}", http_options.deep_merge(:accept_encoding => "gzip"))
    assert_response_code(200, response)
    assert_equal("gzip", response.headers["content-encoding"])
    assert_equal(1000, response.body.bytesize)
  end

  def test_does_not_gzip_response_when_content_length_less_than_1000
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/999?#{unique_test_id}", http_options.deep_merge(:accept_encoding => "gzip"))
    assert_response_code(200, response)
    refute(response.headers["content-encoding"])
    assert_equal(999, response.body.bytesize)
  end

  def test_gzips_chunked_responses_of_any_size
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible-delayed-chunked/5?#{unique_test_id}", http_options.deep_merge(:accept_encoding => "gzip"))
    assert_response_code(200, response)
    assert_equal("chunked", response.headers["transfer-encoding"])
    assert_equal("gzip", response.headers["content-encoding"])
    assert_equal(15, response.body.bytesize)
  end

  def test_returns_unzipped_when_client_does_not_support
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/1000?#{unique_test_id}", http_options)
    assert_response_code(200, response)
    refute(response.headers["content-encoding"])
    assert_equal(1000, response.body.bytesize)
  end
end
