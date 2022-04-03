require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestMultipleLimits < Minitest::Test
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
              :duration => 10 * 1000, # 10 second
              :accuracy => 1000, # 1 second
              :limit_by => "api_key",
              :limit => 3,
              :response_headers => true,
            },
            {
              :duration => 60 * 60 * 1000, # 1 hour
              :accuracy => 1 * 60 * 1000, # 1 minute
              :limit_by => "api_key",
              :limit => 10,
              :response_headers => false,
              :distributed => true,
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

  def test_api_key_rate_limit
    assert_api_key_rate_limit("/api/hello", 3)
  end

  def test_rejects_requests_when_exceeded_in_duration
    api_key = FactoryBot.create(:api_user).api_key
    assert_under_rate_limit("/api/hello", 3, :time => Time.iso8601("2013-01-01T01:27:43Z"), :api_key => api_key)
    assert_over_rate_limit("/api/hello", 7, :time => Time.iso8601("2013-01-01T01:27:43Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-01T01:27:53Z"), :api_key => api_key)
  end

  def test_counts_down_response_header_limits_but_never_negative
    api_key = FactoryBot.create(:api_user).api_key
    remainings = Array.new(5) do |index|
      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
        :headers => {
          "X-Api-Key" => api_key,
        },
      }))

      [response.code, response.headers["x-ratelimit-remaining"]]
    end

    assert_equal([
      [200, "2"],
      [200, "1"],
      [200, "0"],
      [429, "0"],
      [429, "0"],
    ], remainings)
  end
end
