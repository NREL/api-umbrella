require_relative "../../test_helper"

class Test::Proxy::Gzip::TestBackendReturnsForcedPreGzipped < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_underlying_api_is_force_pre_gzipped
    response = Typhoeus.get("http://127.0.0.1:9444/compressible-pre-gzip?force=true", http_options.deep_merge(:accept_encoding => "gzip"))
    assert_response_code(200, response)
    assert_equal("gzip", response.headers["content-encoding"])
    data = MultiJson.load(response.body)
    assert_kind_of(Hash, data["headers"])
    assert_equal("gzip", data["headers"]["accept-encoding"])

    response = Typhoeus.get("http://127.0.0.1:9444/compressible-pre-gzip?force=true", http_options)
    assert_response_code(200, response)
    assert_equal("gzip", response.headers["content-encoding"])
    data = MultiJson.load(Zlib::GzipReader.new(StringIO.new(response.body)).read)
    assert_kind_of(Hash, data["headers"])
    assert_nil(data["headers"]["accept-encoding"])
  end

  def test_returns_gzip_when_client_supports
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible-pre-gzip?force=true", http_options.deep_merge(:accept_encoding => "gzip"))
    assert_response_code(200, response)
    assert_equal("gzip", response.headers["content-encoding"])
    data = MultiJson.load(response.body)
    assert_kind_of(Hash, data["headers"])
    assert_equal("gzip", data["headers"]["accept-encoding"])
  end

  def test_returns_non_gzip_when_client_does_not_support
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible-pre-gzip?force=true", http_options)
    assert_response_code(200, response)
    refute(response.headers["content-encoding"])
    data = MultiJson.load(response.body)
    assert_kind_of(Hash, data["headers"])
    assert_nil(data["headers"]["accept-encoding"])
  end
end
