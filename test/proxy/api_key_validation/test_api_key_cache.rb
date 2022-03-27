require_relative "../../test_helper"

class Test::Proxy::ApiKeyValidation::TestApiKeyCache < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::ExerciseAllWorkers

  def setup
    super
    setup_server
  end

  def test_caches_keys_inside_workers_for_up_to_a_couple_seconds
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :rate_limit_mode => "unlimited",
      }),
    })

    # Make requests against all the workers processes so the key is cache
    # locally inside each worker.
    responses = exercise_all_workers("/api/info/", {
      :headers => { "X-Api-Key" => user.api_key },
      :params => { :step => "pre" },
    })
    responses.each do |response|
      assert_response_code(200, response)
    end

    # Disable the API key
    user.disabled_at = Time.now.utc
    user.save!

    # Immediately make more requests. These may or may not hit cached results,
    # depending on the exact timing of when the
    # `api_users_store_delete_stale_cache` job expires the shared dict cache,
    # and then when the `api_users_store_refresh_local_cache` job updates the
    # local worker caches. But since those jobs execute every 1 second, even if
    # the two jobs are staggered and execute a second apart, the cache
    # shouldn't exceed 2 seconds.
    responses = exercise_all_workers("/api/info/", {
      :headers => { "X-Api-Key" => user.api_key },
      :params => { :step => "post-save" },
    })
    responses.each do |response|
      if response.code == 200
        assert_response_code(200, response)
      else
        assert_response_code(403, response)
        assert_match("API_KEY_DISABLED", response.body)
      end
    end

    # Wait for the cache to expire
    sleep 2.6

    # With the cache expired, now all requests should be rejected due to the
    # disabled key.
    responses = exercise_all_workers("/api/info/", {
      :headers => { "X-Api-Key" => user.api_key },
      :params => { :step => "post-timeout" },
    })
    responses.each do |response|
      assert_response_code(403, response)
      assert_match("API_KEY_DISABLED", response.body)
    end
  end

  def test_keys_across_parallel_hits_with_key_caching
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :rate_limit_mode => "unlimited",
      }),
    })

    hydra = Typhoeus::Hydra.new
    requests = Array.new(20) do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
        :headers => { "X-Api-Key" => user.api_key },
      }))
      hydra.queue(request)
      request
    end
    hydra.run

    requests.each do |request|
      assert_response_code(200, request.response)
      assert_equal("Hello World", request.response.body)
    end
  end

  def test_keys_across_repated_hits_with_key_caching
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :rate_limit_mode => "unlimited",
      }),
    })

    20.times do
      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
        :headers => { "X-Api-Key" => user.api_key },
      }))
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)
    end
  end

  def test_key_caching_disabled
    override_config({
      "gatekeeper" => {
        "api_key_cache" => false,
      },
    }) do
      user = FactoryBot.create(:api_user, {
        :settings => FactoryBot.build(:api_user_settings, {
          :rate_limit_mode => "unlimited",
        }),
      })

      # Make requests against all the workers processes.
      responses = exercise_all_workers("/api/info/", {
        :headers => { "X-Api-Key" => user.api_key },
        :params => { :step => "pre" },
      })
      responses.each do |response|
        assert_response_code(200, response)
      end

      # Disable the API key
      user.disabled_at = Time.now.utc
      user.save!

      # Immediately make more requests. These should still immediately be
      # rejected since the key caching is disabled.
      responses = exercise_all_workers("/api/info/", {
        :headers => { "X-Api-Key" => user.api_key },
        :params => { :step => "post-save" },
      })
      responses.each do |response|
        assert_response_code(403, response)
        assert_match("API_KEY_DISABLED", response.body)
      end
    end
  end
end
