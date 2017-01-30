require_relative "../../test_helper"

class Test::Proxy::Gzip::TestBackendReturnsPreGzipped < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_returns_gzip_when_client_supports
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible-pre-gzip", http_options.deep_merge(:accept_encoding => "gzip"))
    assert_response_code(200, response)
    assert_equal("gzip", response.headers["content-encoding"])
    assert_equal("Hello Small World", response.body)
  end

  def test_returns_non_gzip_when_client_does_not_support
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible-pre-gzip", http_options)
    assert_response_code(200, response)
    refute(response.headers["content-encoding"])
    assert_equal("Hello Small World", response.body)
  end
end
