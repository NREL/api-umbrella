require_relative "../test_helper"

class Test::Proxy::TestBasicAuthPassthrough < Minitest::Test
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
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/add-auth-header/", :backend_prefix => "/" }],
          :settings => {
            :http_basic_auth => "somebody:secret",
          },
        },
      ])
    end
  end

  def test_passes_auth_from_client
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :userpwd => "foo:bar",
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("foo", data["basic_auth_username"])
    assert_equal("bar", data["basic_auth_password"])
  end

  def test_passes_auth_from_proxy
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/add-auth-header/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("somebody", data["basic_auth_username"])
    assert_equal("secret", data["basic_auth_password"])
  end

  def test_replaces_client_auth_with_proxy
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/add-auth-header/info/", http_options.deep_merge({
      :userpwd => "foo:bar",
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("somebody", data["basic_auth_username"])
    assert_equal("secret", data["basic_auth_password"])
  end

  def test_strips_internal_authorization_headers
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/add-auth-header/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    refute(data["headers"]["x-api-umbrella-backend-authorization"])
    refute(data["headers"]["x-api-umbrella-allow-authorization-caching"])
  end
end
