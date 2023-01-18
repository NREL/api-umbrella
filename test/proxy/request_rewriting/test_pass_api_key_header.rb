require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestPassApiKeyHeader < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/pass-api-key-header/", :backend_prefix => "/" }],
          :settings => {
            :pass_api_key_header => true,
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/pass-api-key-header-disabled/", :backend_prefix => "/" }],
          :settings => {
            :pass_api_key_header => false,
          },
        },
      ])
    end
  end

  def test_api_key_given_in_header
    assert(http_options[:headers]["X-Api-Key"])
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-header/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(self.api_key, data["headers"]["x-api-key"])
    assert_equal({}, data["url"]["query"])
  end

  def test_api_key_given_in_query
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-header/info/?api_key=#{self.api_key}", keyless_http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(self.api_key, data["headers"]["x-api-key"])
    assert_equal({}, data["url"]["query"])
  end

  def test_api_key_given_in_basic_auth
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-header/info/", keyless_http_options.deep_merge({
      :userpwd => "#{self.api_key}:",
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(self.api_key, data["headers"]["x-api-key"])
    assert_equal({}, data["url"]["query"])
    refute(data["basic_auth_username"])
    refute(data["headers"]["authorization"])
  end

  def test_disabled
    assert(http_options[:headers]["X-Api-Key"])
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-header-disabled/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_nil(data["headers"]["x-api-key"])
    assert_equal({}, data["url"]["query"])
  end
end
