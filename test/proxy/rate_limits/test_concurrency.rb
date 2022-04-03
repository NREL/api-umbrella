require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestConcurrency < Minitest::Test
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
              :duration => 2 * 60 * 60 * 1000, # 2 hours
              :accuracy => 1 * 60 * 1000, # 1 minute
              :limit_by => "api_key",
              :limit => 50,
              :distributed => false,
              :response_headers => false,
            },
            {
              :duration => 60 * 60 * 1000, # 1 hour
              :accuracy => 1 * 60 * 1000, # 1 minute
              :limit_by => "api_key",
              :limit => 60,
              :distributed => false,
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

  def test_accurately_reports_remaining_requests_across_parallel_requests
    # Generate 48 requests (below rate limit) across 60 different API keys.
    requests = []
    requests_by_key = {}
    60.times do
      api_key = FactoryBot.create(:api_user).api_key
      http_opts = keyless_http_options.deep_merge({
        :headers => {
          "X-Api-Key" => api_key,
        },
      })

      requests_by_key[api_key] = []
      48.times do
        request = Typhoeus::Request.new("http://127.0.0.1:9080/api/hello", http_opts)
        requests << request
        requests_by_key[api_key] << request
      end
    end

    # Randomize the request ordering to mix up the order of API keys.
    requests.shuffle!

    # Make all the requests in parallel, 100 at a time.
    hydra = Typhoeus::Hydra.new(:max_concurrency => 100)
    requests.each do |request|
      hydra.queue(request)
    end
    hydra.run

    # Check the X-RateLimit-Remaining counts for each api key.
    requests_by_key.each_value do |api_key_requests|
      reported_requests_made = 0
      api_key_requests.each do |request|
        assert_response_code(200, request.response)
        assert_equal("60", request.response.headers["x-ratelimit-limit"])
        assert(request.response.headers["x-ratelimit-remaining"])
        count = request.response.headers["x-ratelimit-limit"].to_i - request.response.headers["x-ratelimit-remaining"].to_i
        if(count > reported_requests_made)
          reported_requests_made = count
        end
      end

      assert_operator(reported_requests_made, :>=, 47)
      assert_operator(reported_requests_made, :<=, 48)

      # In some rare situations our internal rate limit counters might be off
      # since we fetch all of our rate limits and then increment them
      # separately. The majority of race conditions should be solved, but one
      # known issue remains that may very rarely lead to this warning (but we
      # don't want to fail the whole test as long as it remains rare). See
      # comments in rate_limit.lua's increment_all_limits().
      if(reported_requests_made == 47)
        puts "WARNING: X-RateLimit-Remaining header was off by 1. This should be very rare. Investigate if you see this with any regularity."
      end
    end
  end

  def test_accurately_blocks_requests_across_parallel_requests
    # Generate 52 requests (exceeding rate limit) across 60 different API keys.
    requests = []
    requests_by_key = {}
    60.times do
      api_key = FactoryBot.create(:api_user).api_key
      http_opts = keyless_http_options.deep_merge({
        :headers => {
          "X-Api-Key" => api_key,
        },
      })

      requests_by_key[api_key] = []
      52.times do
        request = Typhoeus::Request.new("http://127.0.0.1:9080/api/hello", http_opts)
        requests << request
        requests_by_key[api_key] << request
      end
    end

    # Randomize the request ordering to mix up the order of API keys.
    requests.shuffle!

    # Make all the requests in parallel, 100 at a time.
    hydra = Typhoeus::Hydra.new(:max_concurrency => 100)
    requests.each do |request|
      hydra.queue(request)
    end
    hydra.run

    # Ensure each api key got blocked when expected.
    requests_by_key.each_value do |api_key_requests|
      response_codes = api_key_requests.map { |r| r.response.code }
      oks = response_codes.select { |c| c == 200 }.length
      over_rate_limits = response_codes.select { |c| c == 429 }.length
      assert_equal(52, response_codes.length)
      assert_operator(oks, :>=, 50)
      assert_operator(oks, :<=, 51)
      assert_operator(over_rate_limits, :>=, 1)
      assert_operator(over_rate_limits, :<=, 2)

      # In some rare situations our internal rate limit counters might be off
      # since we fetch all of our rate limits and then increment them
      # separately. The majority of race conditions should be solved, but one
      # known issue remains that may very rarely lead to this warning (but we
      # don't want to fail the whole test as long as it remains rare). See
      # comments in rate_limit.lua's increment_all_limits().
      if(over_rate_limits == 1)
        puts "WARNING: Rate limiting was off by 1. This should be very rare. Investigate if you see this with any regularity."
      end
    end
  end
end
