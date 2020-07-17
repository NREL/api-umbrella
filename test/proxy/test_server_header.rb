require_relative "../test_helper"

class Test::Proxy::TestServerHeader < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_sets_server_header_by_default
    response = Typhoeus.get("https://127.0.0.1:9081/api/hello", http_options)
    assert_response_code(200, response)
    assert_includes(response.headers.keys, "Server")
    assert_equal("openresty", response.headers["Server"])
  end

  def test_strip_server_header
    override_config({
      "strip_server_header" => true,
    }) do
      response = Typhoeus.get("https://127.0.0.1:9081/api/hello", http_options)
      assert_response_code(200, response)
      refute_includes(response.headers.keys, "Server")
      assert_nil(response.headers["Server"])
    end
  end
end
