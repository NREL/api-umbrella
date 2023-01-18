require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestUnlimited < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::RateLimits
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        :default_api_backend_settings => {
          :rate_limit_mode => "unlimited",
          :rate_limits => [
            {
              :duration => 60 * 60 * 1000, # 1 hour
              :limit_by => "api_key",
              :limit_to => 5,
              :response_headers => true,
            },
            {
              :duration => 60 * 60 * 1000, # 1 hour
              :limit_by => "ip",
              :limit_to => 5,
            },
          ],
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_unlimited_rate_limit
    assert_unlimited_rate_limit("/api/hello", 5)
  end

  def test_user_with_settings_but_null_rate_limit_mode
    assert_unlimited_rate_limit("/api/hello", 5, {
      :user_factory_overrides => {
        :settings => FactoryBot.build(:api_user_settings, {
          :rate_limit_mode => nil,
        }),
      },
    })
  end
end
