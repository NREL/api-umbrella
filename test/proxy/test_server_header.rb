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

  def test_overrides_api_backend_server_header_by_default
    response = Typhoeus.get("http://127.0.0.1:9080/api/set-http-response-headers/", http_options.deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "http_response_headers" => {
          "Server" => unique_test_id,
        },
      }),
    }))
    assert_response_code(200, response)
    assert_equal("openresty", response.headers.fetch("Server"))
  end

  def test_strip_server_header
    override_config({
      "strip_server_header" => true,
    }) do
      response = Typhoeus.get("https://127.0.0.1:9081/api/hello", http_options)
      assert_response_code(200, response)
      refute_includes(response.headers.keys, "Server")
      assert_nil(response.headers["Server"])

      response = Typhoeus.get("http://127.0.0.1:9080/api/set-http-response-headers/", http_options.deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "http_response_headers" => {
            "Server" => unique_test_id,
          },
        }),
      }))
      assert_response_code(200, response)
      refute_includes(response.headers.keys, "Server")
      assert_nil(response.headers["Server"])
    end
  end
end
