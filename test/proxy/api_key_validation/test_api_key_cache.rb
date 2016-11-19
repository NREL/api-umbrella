require_relative "../../test_helper"

class TestProxyApiKeyValidationApiKeyCache < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
  end

  def test_caches_keys_inside_workers_for_couple_seconds
    user = FactoryGirl.create(:api_user, :settings => {
      :rate_limit_mode => "unlimited",
    })

    # Make requests against all the workers processes so the key is cache
    # locally inside each worker.
    requests = exercise_all_workers(user.api_key, "pre")
    requests.each do |request|
      assert_equal(200, request.response.code, request.response.body)
    end

    # Disable the API key
    user.disabled_at = Time.now.utc
    user.save!

    # Immediately make more requests. These should still succeed due to the
    # local cache.
    requests = exercise_all_workers(user.api_key, "post-save")
    requests.each do |request|
      assert_equal(200, request.response.code, request.response.body)
    end

    # Wait for the cache to expire
    sleep 2.1

    # With the cache expired, now all requests should be rejected due to the
    # disabled key.
    requests = exercise_all_workers(user.api_key, "post-timeout")
    requests.each do |request|
      assert_equal(403, request.response.code, request.response.body)
      assert_match("API_KEY_DISABLED", request.response.body)
    end
  end

  def test_keys_across_parallel_hits_with_key_caching
    user = FactoryGirl.create(:api_user, :settings => {
      :rate_limit_mode => "unlimited",
    })

    hydra = Typhoeus::Hydra.new
    requests = Array.new(20) do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/hello", self.http_options.deep_merge({
        :headers => {
          "X-Api-Key" => user.api_key,
        },
      }))
      hydra.queue(request)
      request
    end
    hydra.run

    requests.each do |request|
      assert_equal(200, request.response.code, request.response.body)
      assert_equal("Hello World", request.response.body)
    end
  end

  def test_keys_across_repated_hits_with_key_caching
    user = FactoryGirl.create(:api_user, :settings => {
      :rate_limit_mode => "unlimited",
    })

    20.times do
      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", self.http_options.deep_merge({
        :headers => {
          "X-Api-Key" => user.api_key,
        },
      }))
      assert_equal(200, response.code, response.body)
      assert_equal("Hello World", response.body)
    end
  end

  def test_key_caching_disabled
    override_config({
      "gatekeeper" => {
        "api_key_cache" => false,
      },
    }, "--router") do
      user = FactoryGirl.create(:api_user, :settings => {
        :rate_limit_mode => "unlimited",
      })

      # Make requests against all the workers processes.
      requests = exercise_all_workers(user.api_key, "pre")
      requests.each do |request|
        assert_equal(200, request.response.code, request.response.body)
      end

      # Disable the API key
      user.disabled_at = Time.now.utc
      user.save!

      # Immediately make more requests. These should still immediately be
      # rejected since the key caching is disabled.
      requests = exercise_all_workers(user.api_key, "post-save")
      requests.each do |request|
        assert_equal(403, request.response.code, request.response.body)
        assert_match("API_KEY_DISABLED", request.response.body)
      end
    end
  end

  private

  def exercise_all_workers(api_key, step)
    requests = []
    ids_seen = Set.new
    pids_seen = Set.new
    begin
      Timeout.timeout(10) do
        loop do
          request = Typhoeus::Request.new("http://127.0.0.1:9080/api/info/?#{unique_test_id}-#{step}", self.http_options.deep_merge({
            :headers => {
              "X-Api-Key" => api_key,
              # Return debug information on the responses about which nginx
              # worker process was used for the request.
              "X-Api-Umbrella-Test-Debug-Workers" => "true",
              # Don't use keepalive connections. This helps hit all the worker
              # processes more quickly.
              "Connection" => "close",
            },
          }))
          request.run
          if(request.response.headers["x-api-umbrella-test-worker-id"])
            ids_seen << request.response.headers["x-api-umbrella-test-worker-id"]
          end
          if(request.response.headers["x-api-umbrella-test-worker-pid"])
            pids_seen << request.response.headers["x-api-umbrella-test-worker-pid"]
          end
          requests << request

          if(ids_seen.length == $config["nginx"]["workers"] && pids_seen.length >= $config["nginx"]["workers"])
            break
          end
        end
      end
    rescue Timeout::Error
      raise Timeout::Error, "All nginx workers not hit. Expected workers: #{$config["nginx"]["workers"]} Worker IDs seen: #{ids_seen.to_a.inspect} Worker PIDs seen: #{pids_seen.to_a.inspect}"
    end

    requests
  end
end
