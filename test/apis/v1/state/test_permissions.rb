require_relative "../../../test_helper"

class Test::Apis::V1::State::TestPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_allows_without_api_key
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/state", keyless_http_options)
    assert_response_code(200, response)
    assert_equal("application/json", response.headers["Content-Type"])
  end

  def test_allows_with_api_key_without_roles
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/state", http_options)
    assert_response_code(200, response)
    assert_equal("application/json", response.headers["Content-Type"])
  end
end
