require_relative "../test_helper"

class Test::Proxy::TestChunkedResponses < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_small_non_chunked_response_no_gzip
    assert_non_chunked_response("/api/compressible/10", 10)
  end

  def test_small_non_chunked_response_gzip
    assert_non_chunked_response("/api/compressible/10", 10, :accept_encoding => "gzip")
  end

  def test_large_non_chunked_response_no_gzip
    assert_non_chunked_response("/api/compressible/100000", 100000)
  end

  def test_large_non_chunked_response_gzip
    # nginx's gzipping chunks larger responses, even if they weren't before.
    assert_chunked_response("/api/compressible/100000", 100000, :accept_encoding => "gzip")
  end

  def test_small_chunked_response_no_gzip
    assert_chunked_response("/api/compressible-chunked/1/500", 500)
  end

  def test_small_chunked_response_gzip
    assert_chunked_response("/api/compressible-chunked/1/500", 500, :accept_encoding => "gzip")
  end

  def test_large_chunked_response_no_gzip
    assert_chunked_response("/api/compressible-chunked/50/2000", 100000)
  end

  def test_large_chunked_response_gzip
    assert_chunked_response("/api/compressible-chunked/50/2000", 100000, :accept_encoding => "gzip")
  end

  private

  def assert_chunked_response(path, expected_body_size, options = {})
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge(options))
    assert_equal(200, response.code, response.body)
    assert_equal("chunked", response.headers["transfer-encoding"])
    refute(response.headers["content-length"])
    assert_equal(expected_body_size, response.body.bytesize)
  end

  def assert_non_chunked_response(path, expected_body_size, options = {})
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge(options))
    assert_equal(200, response.code, response.body)
    refute(response.headers["transfer-encoding"])
    assert_equal(expected_body_size.to_s, response.headers["content-length"])
    assert_equal(expected_body_size, response.body.bytesize)
  end
end
