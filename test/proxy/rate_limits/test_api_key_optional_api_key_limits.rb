require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestApiKeyOptionalApiKeyLimits < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::RateLimits
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        :default_api_backend_settings => {
          :rate_limits => [
            {
              :duration => 60 * 60 * 1000, # 1 hour
              :accuracy => 1 * 60 * 1000, # 1 minute
              :limit_by => "api_key",
              :limit_to => 5,
              :distributed => true,
              :response_headers => true,
            },
            {
              :duration => 60 * 60 * 1000, # 1 hour
              :accuracy => 1 * 60 * 1000, # 1 minute
              :limit_by => "ip",
              :limit_to => 7,
              :distributed => true,
              :response_headers => false,
            },
          ],
        },
      })

      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/no-keys-default/", :backend_prefix => "/" }],
          :settings => {
            :disable_api_key => true,
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/no-keys-ip-fallback/", :backend_prefix => "/" }],
          :settings => {
            :disable_api_key => true,
            :anonymous_rate_limit_behavior => "ip_fallback",
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/no-keys-ip-only/", :backend_prefix => "/" }],
          :settings => {
            :disable_api_key => true,
            :anonymous_rate_limit_behavior => "ip_only",
          },
        },
      ])
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_default_anonymous_behavior_api_key_provided
    assert_api_key_rate_limit("/#{unique_test_class_id}/no-keys-default/hello", 5)
  end

  def test_default_anonymous_behavior_api_key_ommitted
    assert_ip_rate_limit("/#{unique_test_class_id}/no-keys-default/hello", 5, :omit_api_key => true)
  end

  def test_ip_fallback_anonymous_behavior_api_key_provided
    assert_api_key_rate_limit("/#{unique_test_class_id}/no-keys-ip-fallback/hello", 5)
  end

  def test_ip_fallback_anonymous_behavior_api_key_ommitted
    assert_ip_rate_limit("/#{unique_test_class_id}/no-keys-ip-fallback/hello", 5, :omit_api_key => true)
  end

  def test_ip_only_anonymous_behavior_api_key_provided
    assert_api_key_rate_limit("/#{unique_test_class_id}/no-keys-ip-only/hello", 5)
  end

  def test_ip_only_anonymous_behavior_api_key_ommitted
    assert_ip_rate_limit("/#{unique_test_class_id}/no-keys-ip-only/hello", 7, :omit_api_key => true, :no_response_headers => true)
  end
end
