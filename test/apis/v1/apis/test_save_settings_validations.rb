require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveSettingsValidations < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::ApiSaveValidations
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_accepts_valid_rate_limit_settings
    assert_valid({
      :settings => FactoryBot.attributes_for(:custom_rate_limit_api_backend_settings),
    })
  end

  def test_rejects_duplicate_rate_limit_durations
    assert_invalid({
      :settings => FactoryBot.attributes_for(:custom_rate_limit_api_backend_settings, {
        :rate_limits => [
          FactoryBot.attributes_for(:rate_limit, :duration => 1000),
          FactoryBot.attributes_for(:rate_limit, :duration => 1000),
        ],
      }),
    }, ["rate_limits[1].duration"])
  end

  def test_accepts_duplicate_rate_limit_durations_with_differing_limit_by
    assert_valid({
      :settings => FactoryBot.attributes_for(:custom_rate_limit_api_backend_settings, {
        :rate_limits => [
          FactoryBot.attributes_for(:rate_limit, :duration => 1000, :limit_by => "ip"),
          FactoryBot.attributes_for(:rate_limit, :duration => 1000, :limit_by => "api_key"),
        ],
      }),
    })
  end

  def test_accepts_duplicate_rate_limit_durations_on_different_apis
    assert_valid({
      :settings => FactoryBot.attributes_for(:custom_rate_limit_api_backend_settings, {
        :rate_limits => [
          FactoryBot.attributes_for(:rate_limit, :duration => 1000),
        ],
      }),
    })
    assert_valid({
      :settings => FactoryBot.attributes_for(:custom_rate_limit_api_backend_settings, {
        :rate_limits => [
          FactoryBot.attributes_for(:rate_limit, :duration => 1000),
        ],
      }),
    })
  end
end
