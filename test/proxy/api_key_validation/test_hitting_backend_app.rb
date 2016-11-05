require_relative "../../test_helper"

class TestProxyApiKeyValidationHittingBackendApp < Minitest::Test
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
  end

  def test_does_not_hit_backend_app_when_denied
    response = Typhoeus.get("http://127.0.0.1:9442/reset_backend_called")
    assert_equal(200, response.code, response.body)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_called")
    assert_equal(200, response.code, response.body)
    assert_equal("false", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", self.http_options.except(:headers))
    assert_equal(403, response.code, response.body)
    assert_match("API_KEY_MISSING", response.body)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_called")
    assert_equal(200, response.code, response.body)
    assert_equal("false", response.body)
  end

  def test_hits_backend_app_when_allowed
    response = Typhoeus.get("http://127.0.0.1:9442/reset_backend_called")
    assert_equal(200, response.code, response.body)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_called")
    assert_equal(200, response.code, response.body)
    assert_equal("false", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", self.http_options)
    assert_equal(200, response.code, response.body)
    assert_equal("Hello World", response.body)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_called")
    assert_equal(200, response.code, response.body)
    assert_equal("true", response.body)
  end
end
