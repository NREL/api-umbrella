require_relative "../../test_helper"

class Test::Proxy::ApiKeyValidation::TestOptionalKeys < Minitest::Test
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
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/no-keys/", :backend_prefix => "/" }],
          :settings => {
            :disable_api_key => true,
            :rate_limit_mode => "unlimited",
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "force_disabled=true",
              :settings => {
                :disable_api_key => true,
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/nevermind",
              :settings => {
                :disable_api_key => false,
              },
            },
            {
              :http_method => "POST",
              :regex => "^/hello/post-required",
              :settings => {
                :disable_api_key => false,
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/inherit",
              :settings => {
                :disable_api_key => nil,
              },
            },
          ],
        },
      ])
    end
  end

  def test_required_by_default
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)
  end

  def test_disabled_for_specific_backend
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello", keyless_http_options)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_still_validates_key_if_not_required_but_given
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => "invalid",
      },
    }))
    assert_response_code(403, response)
    assert_match("API_KEY_INVALID", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => self.api_key,
      },
    }))
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_sub_url_settings_inherits_when_null
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello/inherit", keyless_http_options)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_sub_url_settings_overrides_parent_settings
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello/nevermind", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)
  end

  def test_sub_url_settings_matches_in_order
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello/nevermind?force_disabled=true", keyless_http_options)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_sub_url_settings_matches_based_on_http_method
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello/post-required", keyless_http_options)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)

    response = Typhoeus.post("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello/post-required", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)
  end

  def test_sub_url_settings_do_not_affect_subsequent_parent_calls
    response = Typhoeus.post("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello/post-required", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/no-keys/hello", keyless_http_options)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end
end
