require_relative "../../test_helper"

class Test::Proxy::ApiKeyValidation::TestInputMethods < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_http_header
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "X-Api-Key" => self.api_key,
      },
    }))
    assert_response_code(200, response)
    assert_match("Hello World", response.body)
  end

  def test_get_query_param
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :params => {
        :api_key => self.api_key,
      },
    }))
    assert_response_code(200, response)
    assert_match("Hello World", response.body)
  end

  def test_http_basic_auth_username
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :userpwd => "#{self.api_key}:",
    }))
    assert_response_code(200, response)
    assert_match("Hello World", response.body)
  end

  def test_prefers_http_header_over_all_others
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "X-Api-Key" => self.api_key,
      },
      :params => {
        :api_key => "invalid",
      },
      :userpwd => "invalid:",
    }))
    assert_response_code(200, response)
    assert_match("Hello World", response.body)
  end

  def test_prefers_query_param_over_basic_auth
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :params => {
        :api_key => self.api_key,
      },
      :userpwd => "invalid:",
    }))
    assert_response_code(200, response)
    assert_match("Hello World", response.body)
  end
end
