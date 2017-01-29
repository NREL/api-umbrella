require_relative "../../test_helper"

class Test::Proxy::ApiKeyValidation::TestHittingBackendApp < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_does_not_hit_backend_app_when_denied
    response = Typhoeus.get("http://127.0.0.1:9442/reset_backend_called")
    assert_response_code(200, response)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_called")
    assert_response_code(200, response)
    assert_equal("false", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_called")
    assert_response_code(200, response)
    assert_equal("false", response.body)
  end

  def test_hits_backend_app_when_allowed
    response = Typhoeus.get("http://127.0.0.1:9442/reset_backend_called")
    assert_response_code(200, response)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_called")
    assert_response_code(200, response)
    assert_equal("false", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_called")
    assert_response_code(200, response)
    assert_equal("true", response.body)
  end
end
