require_relative "../../test_helper"

class TestProxyRequestRewritingSetsHttpBasicAuth < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/empty/", :backend_prefix => "/" }],
          :settings => {
            :http_basic_auth => "",
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/invalid/", :backend_prefix => "/" }],
          :settings => {
            :http_basic_auth => "anotheruser:invalid",
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/", :backend_prefix => "/" }],
          :settings => {
            :http_basic_auth => "somebody:secret",
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/auth/sub/",
              :settings => {
                :http_basic_auth => "anotheruser:anothersecret",
              },
            },
          ],
        },
      ])
    end
  end

  def test_sets_auth
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/auth/", self.http_options)
    assert_equal(200, response.code, response.body)
    assert_equal("somebody", response.body)
  end

  def test_overrides_existing_auth
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/auth/", self.http_options.deep_merge({
      :userpwd => "testuser:testpass",
    }))
    assert_equal(200, response.code, response.body)
    assert_equal("somebody", response.body)
  end

  def test_sub_url_settings_overrides_parent_settings
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/auth/sub/", self.http_options)
    assert_equal(200, response.code, response.body)
    assert_equal("anotheruser", response.body)
  end

  def test_does_not_pass_auth_when_empty_string
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/empty/info/", self.http_options)
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    refute(data["headers"]["authorization"])
  end

  def test_passes_unauthorized_error_from_backend_if_auth_is_invalid
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/invalid/auth/", self.http_options)
    assert_equal(401, response.code, response.body)
    assert_equal("Unauthorized", response.body)
  end
end
