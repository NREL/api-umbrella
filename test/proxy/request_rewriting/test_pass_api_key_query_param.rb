require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestPassApiKeyQueryParam < Minitest::Test
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
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/pass-api-key-query-param/", :backend_prefix => "/" }],
          :settings => {
            :pass_api_key_query_param => true,
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/pass-api-key-query-param-disabled/", :backend_prefix => "/" }],
          :settings => {
            :pass_api_key_query_param => false,
          },
        },
      ])
    end
  end

  def test_api_key_given_in_header
    assert(http_options[:headers]["X-Api-Key"])
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-query-param/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({ "api_key" => self.api_key }, data["url"]["query"])
    refute(data["headers"]["x-api-key"])
  end

  def test_api_key_given_in_query
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-query-param/info/?api_key=#{self.api_key}", keyless_http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({ "api_key" => self.api_key }, data["url"]["query"])
    refute(data["headers"]["x-api-key"])
  end

  def test_api_key_given_in_basic_auth
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-query-param/info/", keyless_http_options.deep_merge({
      :userpwd => "#{self.api_key}:",
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({ "api_key" => self.api_key }, data["url"]["query"])
    refute(data["headers"]["x-api-key"])
    refute(data["basic_auth_username"])
    refute(data["headers"]["authorization"])
  end

  def test_overwrites_invalid_key_in_query_with_valid_key_from_header
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-query-param/info/?api_key=foo", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({ "api_key" => self.api_key }, data["url"]["query"])
    refute(data["headers"]["x-api-key"])
  end

  def test_preserves_query_string_order
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-query-param/info/?ccc=foo&aaa=bar&b=test", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("http://127.0.0.1/info/?ccc=foo&aaa=bar&b=test&api_key=#{self.api_key}", data["raw_url"])
  end

  def test_disabled
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/pass-api-key-query-param-disabled/info/?api_key=#{self.api_key}", keyless_http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({}, data["url"]["query"])
    refute(data["headers"]["x-api-key"])
  end
end
