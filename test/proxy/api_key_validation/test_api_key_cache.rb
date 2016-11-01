require_relative "../../test_helper"

class TestProxyApiKeyValidationApiKeyCache < Minitest::Test
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
  end

  def test_caches_keys_inside_workers_for_couple_seconds
    user = FactoryGirl.create(:api_user, :settings => {
      :rate_limit_mode => "unlimited",
    })

    # Fire off a number of parallel requests so we should hit all the
    # individual worker processes.
    requests = exercise_all_workers(user.api_key, "pre")
    requests.each do |request|
      assert_equal(200, request.response.code, request.response.body)
    end

    # Disable the API key
    user.disabled_at = Time.now.utc
    user.save!

    # Make more requests across all the workers while the key should still be
    # cached.
    requests = exercise_all_workers(user.api_key, "post-save")
    response_codes = requests.map { |r| r.response.code }
    oks = response_codes.select { |c| c == 200 }.length
    # Ensure that at least some of the responses are still successes (due to
    # the cache). Most of the time, all the responses should be successful, but
    # on the off-chance our initial batch of requests didn't hit some of the
    # nginx worker processes, that means the api key won't be cached under that
    # worker process, so it will be returning errors immediately (but that's
    # okay, since all we're really wanting to test is the fact that the cache
    # is present).
    assert_operator(oks, :>=, 1)

    # Wait for the cache to expire
    sleep 2.1

    # Make more parallel requests to ensure all the workers have expired their
    # cache and all consider the key to be disabled.
    requests = exercise_all_workers(user.api_key, "post-timeout")
    requests.each do |request|
      assert_equal(403, request.response.code, request.response.body)
      assert_match("API_KEY_DISABLED", request.response.body)
    end
  end

  private

  def exercise_all_workers(api_key, step)
    hydra = Typhoeus::Hydra.new(:max_concurrency => 10)
    requests = Array.new(250) do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/hello?#{unique_test_id}-#{step}", self.http_options.deep_merge({
        :headers => {
          "X-Api-Key" => api_key,
        },
      }))
      hydra.queue(request)
      request
    end
    hydra.run

    requests
  end
end
