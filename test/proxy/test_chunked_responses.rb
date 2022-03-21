require_relative "../test_helper"

class Test::Proxy::TestChunkedResponses < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
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

  # Varnish 3 exhibited invalid responses when streaming was enabled and
  # dealing with gzipped, chunked responses:
  # https://www.varnish-cache.org/trac/ticket/1220
  #
  # We're no longer using Varnish 3, but still test for this to ensure our
  # stack remains compatible with this scenario.
  def test_large_chunked_response_gzip_sanity
    # Varnish 3's broken behavior only cropped up sporadically, but larger
    # responses seem to have triggered the behavior more frequently. Responses
    # somewhere in the neighborhood of 252850 bytes seemed to make this problem
    # reproducible. So test everything from 252850 - 253850 bytes.
    hydra = Typhoeus::Hydra.new
    requests = Array.new(1000) do |i|
      size = 252850 + i
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/compressible-chunked/1/#{size}", http_options.deep_merge(:accept_encoding => "gzip"))
      hydra.queue(request)
      request
    end
    hydra.run

    assert_equal(1000, requests.length)
    requests.each_with_index do |request, i|
      size = 252850 + i
      assert_response_code(200, request.response)
      assert_equal("chunked", request.response.headers["transfer-encoding"])
      assert_equal("gzip", request.response.headers["content-encoding"])
      assert_equal(size, request.response.body.bytesize)
    end
  end

  private

  def assert_chunked_response(path, expected_body_size, options = {})
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge(options))
    assert_response_code(200, response)
    assert_equal("chunked", response.headers["transfer-encoding"])
    refute(response.headers["content-length"])
    assert_equal(expected_body_size, response.body.bytesize)
  end

  def assert_non_chunked_response(path, expected_body_size, options = {})
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge(options))
    assert_response_code(200, response)
    refute(response.headers["transfer-encoding"])
    assert_equal(expected_body_size.to_s, response.headers["content-length"])
    assert_equal(expected_body_size, response.body.bytesize)
  end
end
