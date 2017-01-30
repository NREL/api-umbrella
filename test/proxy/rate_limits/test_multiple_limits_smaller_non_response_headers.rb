require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestMultipleLimitsSmallerNonResponseHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::RateLimits
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        :apiSettings => {
          :rate_limits => [
            {
              :duration => 10 * 1000, # 10 second
              :accuracy => 1000, # 1 second
              :limit_by => "apiKey",
              :limit => 3,
              :response_headers => false,
            },
            {
              :duration => 60 * 60 * 1000, # 1 hour
              :accuracy => 1 * 60 * 1000, # 1 minute
              :limit_by => "apiKey",
              :limit => 10,
              :response_headers => true,
              :distributed => true,
            },
          ],
        },
      }, "--router")
    end
  end

  def after_all
    super
    override_config_reset("--router")
  end

  def test_api_key_rate_limit
    assert_api_key_rate_limit("/api/hello", 3, :response_header_limit => 10)
  end
end
