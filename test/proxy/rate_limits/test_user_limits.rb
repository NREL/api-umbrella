require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestUserLimits < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::RateLimits
  include ApiUmbrellaTestHelpers::ExerciseAllWorkers
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
          ],
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_non_user_default_limit
    assert_api_key_rate_limit("/api/hello", 5)
  end

  def test_user_throttle_by_ip
    assert_ip_rate_limit("/api/hello", 5, {
      :user_factory_overrides => {
        :throttle_by_ip => true,
      },
    })
  end

  def test_user_unlimited
    assert_unlimited_rate_limit("/api/hello", 5, {
      :user_factory_overrides => {
        :settings => FactoryBot.build(:api_user_settings, {
          :rate_limit_mode => "unlimited",
        }),
      },
    })
  end

  def test_user_custom_limit
    assert_api_key_rate_limit("/api/hello", 10, {
      :user_factory_overrides => {
        :settings => FactoryBot.build(:api_user_settings, {
          :rate_limits => [
            FactoryBot.build(:rate_limit, {
              :duration => 60 * 60 * 1000, # 1 hour
              :accuracy => 1 * 60 * 1000, # 1 minute
              :limit_by => "api_key",
              :limit_to => 10,
              :distributed => true,
              :response_headers => true,
            }),
          ],
        }),
      },
    })
  end

  def test_live_changes_within_2_seconds
    user = FactoryBot.create(:api_user, :settings => FactoryBot.build(:api_user_settings, {
      :rate_limits => [
        FactoryBot.build(:rate_limit, {
          :duration => 60 * 60 * 1000, # 1 hour
          :accuracy => 1 * 60 * 1000, # 1 minute
          :limit_by => "api_key",
          :limit_to => 10,
          :distributed => true,
          :response_headers => true,
        }),
      ],
    }))
    http_opts = keyless_http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user.api_key,
      },
    })

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_opts)
    assert_equal("10", response.headers["x-ratelimit-limit"])

    user.settings.rate_limits[0].limit_to = 90
    user.settings.rate_limits[0].save!

    # Wait for any local caches to expire (2 seconds).
    sleep 2.6

    # Make sure any local worker cache is cleared across all possible worker
    # processes.
    responses = exercise_all_workers("/api/info/", http_opts)
    responses.each do |resp|
      assert_equal("90", resp.headers["x-ratelimit-limit"])
    end
  end
end
