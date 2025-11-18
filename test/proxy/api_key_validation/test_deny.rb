require_relative "../../test_helper"

class Test::Proxy::ApiKeyValidation::TestDeny < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_no_api_key
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)
  end

  def test_empty_api_key
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge(empty_http_header_options("X-Api-Key")))
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)
  end

  def test_invalid_api_key
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "X-Api-Key" => "invalid",
      },
    }))
    assert_response_code(403, response)
    assert_match("API_KEY_INVALID", response.body)
  end

  def test_disabled_api_key
    user = FactoryBot.create(:api_user, :disabled_at => Time.now.utc)
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user.api_key,
      },
    }))
    assert_response_code(403, response)
    assert_match("API_KEY_DISABLED", response.body)
  end
end
