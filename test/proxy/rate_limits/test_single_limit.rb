require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestSingleLimit < Minitest::Test
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
              :limit_by => "api_key",
              :limit_to => 10,
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

  def test_api_key_rate_limit
    assert_api_key_rate_limit("/api/hello", 10)
  end

  def test_rejects_single_time_period_rate_above_limit
    api_key = FactoryBot.create(:api_user).api_key
    assert_under_rate_limit("/api/hello", 10, :time => Time.iso8601("2013-01-01T01:27:00Z"), :api_key => api_key)
    assert_over_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-01T01:59:59Z"), :api_key => api_key)
  end

  def test_rejects_estimated_rate_above_limit_full_previous_period_count
    api_key = FactoryBot.create(:api_user).api_key
    assert_under_rate_limit("/api/hello", 10, :time => Time.iso8601("2013-01-01T01:27:00Z"), :api_key => api_key)
    assert_over_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-01T02:00:00Z"), :api_key => api_key)
  end

  def test_allows_estimated_rate_below_limit
    api_key = FactoryBot.create(:api_user).api_key
    assert_under_rate_limit("/api/hello", 10, :time => Time.iso8601("2013-01-01T01:27:00Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-01T02:00:01Z"), :api_key => api_key)
  end

  def test_rejects_estimated_rate_above_limit_partial_previous_period_count
    api_key = FactoryBot.create(:api_user).api_key
    assert_under_rate_limit("/api/hello", 10, :time => Time.iso8601("2013-01-01T01:27:00Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-01T02:05:59Z"), :api_key => api_key)
    assert_over_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-01T02:06:00Z"), :api_key => api_key)
  end

  def test_allows_requests_after_time_expires
    api_key = FactoryBot.create(:api_user).api_key
    assert_under_rate_limit("/api/hello", 10, :time => Time.iso8601("2013-01-01T01:27:00Z"), :api_key => api_key)
    assert_over_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-01T01:27:00Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-01T02:27:00Z"), :api_key => api_key)
  end

  def test_resets_rate_limits_on_rolling_basis_from_estimated_rate
    api_key = FactoryBot.create(:api_user).api_key
    assert_under_rate_limit("/api/hello", 9, :time => Time.iso8601("2013-01-02T01:43:00Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 2, :time => Time.iso8601("2013-01-02T02:03:00Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 6, :time => Time.iso8601("2013-01-02T02:42:00Z"), :api_key => api_key)
    assert_over_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-02T02:46:00Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-02T02:47:00Z"), :api_key => api_key)
    assert_over_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-02T02:47:00Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-02T02:59:00Z"), :api_key => api_key)
    assert_over_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-02T03:00:00Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-02T03:02:00Z"), :api_key => api_key)
    assert_under_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-02T03:07:00Z"), :api_key => api_key)
    assert_over_rate_limit("/api/hello", 1, :time => Time.iso8601("2013-01-02T03:07:00Z"), :api_key => api_key)
  end

  def test_live_changes
    http_opts = keyless_http_options.deep_merge({
      :headers => {
        "X-Api-Key" => FactoryBot.create(:api_user).api_key,
      },
    })

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_opts)
    assert_equal("10", response.headers["x-ratelimit-limit"])

    override_config({
      "default_api_backend_settings" => {
        "rate_limits" => [
          {
            "duration" => 60 * 60 * 1000, # 1 hour
            "limit_by" => "api_key",
            "limit_to" => 70,
            "distributed" => true,
            "response_headers" => true,
          },
        ],
      },
    }) do
      # Make sure any local worker cache is cleared across all possible worker
      # processes.
      responses = exercise_all_workers("/api/info/", http_opts)
      responses.each do |resp|
        assert_equal("70", resp.headers["x-ratelimit-limit"])
      end
    end

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_opts)
    assert_equal("10", response.headers["x-ratelimit-limit"])
  end
end
