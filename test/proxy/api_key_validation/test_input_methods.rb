require_relative "../../test_helper"

class TestProxyApiKeyValidationInputMethods < Minitest::Test
  include ApiUmbrellaTests::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_http_header
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", self.http_options.except(:headers).deep_merge({
      :headers => {
        "X-Api-Key" => self.api_key,
      },
    }))
    assert_equal(200, response.code, response.body)
    assert_match("Hello World", response.body)
  end

  def test_get_query_param
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", self.http_options.except(:headers).deep_merge({
      :params => {
        :api_key => self.api_key,
      },
    }))
    assert_equal(200, response.code, response.body)
    assert_match("Hello World", response.body)
  end

  def test_http_basic_auth_username
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", self.http_options.except(:headers).deep_merge({
      :userpwd => "#{self.api_key}:",
    }))
    assert_equal(200, response.code, response.body)
    assert_match("Hello World", response.body)
  end

  def test_prefers_http_header_over_all_others
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", self.http_options.except(:headers).deep_merge({
      :headers => {
        "X-Api-Key" => self.api_key,
      },
      :params => {
        :api_key => "invalid",
      },
      :userpwd => "invalid:",
    }))
    assert_equal(200, response.code, response.body)
    assert_match("Hello World", response.body)
  end

  def test_prefers_query_param_over_basic_auth
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", self.http_options.except(:headers).deep_merge({
      :params => {
        :api_key => self.api_key,
      },
      :userpwd => "invalid:",
    }))
    assert_equal(200, response.code, response.body)
    assert_match("Hello World", response.body)
  end
end
