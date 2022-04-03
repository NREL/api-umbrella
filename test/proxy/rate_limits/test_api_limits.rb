require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestApiLimits < Minitest::Test
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
              :limit => 5,
              :distributed => true,
              :response_headers => true,
            },
          ],
        },
      })

      prepend_api_backends([
        {
          :name => "#{unique_test_class_id} - Lower",
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/lower/", :backend_prefix => "/" }],
          :settings => {
            :rate_limits => [
              {
                :duration => 60 * 60 * 1000, # 1 hour
                :accuracy => 1 * 60 * 1000, # 1 minute
                :limit_by => "api_key",
                :limit => 3,
                :distributed => true,
                :response_headers => true,
              },
            ],
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/hello/sub-higher",
              :settings => {
                :rate_limits => [
                  {
                    :duration => 60 * 60 * 1000, # 1 hour
                    :accuracy => 1 * 60 * 1000, # 1 minute
                    :limit_by => "api_key",
                    :limit => 7,
                    :distributed => true,
                    :response_headers => true,
                  },
                ],
              },
            },
          ],
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/different-bucket/", :backend_prefix => "/" }],
          :settings => {
            :rate_limit_bucket_name => "different",
          },
        },
        {
          :frontend_host => "*",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/wildcard/", :backend_prefix => "/wildcard/" }],
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/", :backend_prefix => "/" }],
        },
        {
          :frontend_host => "some.gov",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/some.gov-more-specific-backend/", :backend_prefix => "/" }],
        },
        {
          :frontend_host => "some.gov",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/", :backend_prefix => "/" }],
        },
      ])
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_non_api_default_limit
    assert_api_key_rate_limit("/api/hello", 5)
  end

  def test_api_with_lower_limit
    assert_api_key_rate_limit("/#{unique_test_class_id}/lower/hello", 3)
  end

  def test_sub_settings_with_higher_limit
    assert_api_key_rate_limit("/#{unique_test_class_id}/lower/hello/sub-higher", 7)
  end

  def test_counts_explicit_buckets_differently
    http_opts = keyless_http_options.deep_merge({
      :headers => { "X-Api-Key" => FactoryBot.create(:api_user).api_key },
    })

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_opts)
    assert_equal("4", response.headers["x-ratelimit-remaining"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_opts)
    assert_equal("3", response.headers["x-ratelimit-remaining"])

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/different-bucket/hello", http_opts)
    assert_equal("4", response.headers["x-ratelimit-remaining"])
  end

  def test_gives_each_domain_separate_bucket
    http_opts = keyless_http_options.deep_merge({
      :headers => { "X-Api-Key" => FactoryBot.create(:api_user).api_key },
    })

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_opts)
    assert_equal("4", response.headers["x-ratelimit-remaining"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_opts)
    assert_equal("3", response.headers["x-ratelimit-remaining"])

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/hello", http_opts.deep_merge({
      :headers => { "Host" => "some.gov" },
    }))
    assert_equal("4", response.headers["x-ratelimit-remaining"])
  end

  def test_multiple_backends_under_single_domain_use_same_bucket
    http_opts = keyless_http_options.deep_merge({
      :headers => {
        "X-Api-Key" => FactoryBot.create(:api_user).api_key,
        "Host" => "some.gov",
      },
    })

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/hello", http_opts)
    assert_equal("4", response.headers["x-ratelimit-remaining"])

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/some.gov-more-specific-backend/hello", http_opts)
    assert_equal("3", response.headers["x-ratelimit-remaining"])
  end

  def test_wildcard_domains_on_backend_use_same_bucket
    http_opts = keyless_http_options.deep_merge({
      :headers => { "X-Api-Key" => FactoryBot.create(:api_user).api_key },
    })

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/wildcard/hello", http_opts.deep_merge({
      :headers => { "Host" => "wildcard.example.wild" },
    }))
    assert_equal("4", response.headers["x-ratelimit-remaining"])

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/wildcard/hello", http_opts.deep_merge({
      :headers => { "Host" => "wildcard2.example.wild" },
    }))
    assert_equal("3", response.headers["x-ratelimit-remaining"])
  end

  def test_user_with_empty_rate_limits_array
    assert_api_key_rate_limit("/#{unique_test_class_id}/lower/hello", 3, {
      :user_factory_overrides => {
        :settings => FactoryBot.build(:api_user_settings, {
          :rate_limit_mode => nil,
          :rate_limits => [],
        }),
      },
    })
  end

  def test_live_changes
    http_opts = keyless_http_options.deep_merge({
      :headers => {
        "X-Api-Key" => FactoryBot.create(:api_user).api_key,
      },
    })

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/lower/info/", http_opts)
    assert_equal("3", response.headers["x-ratelimit-limit"])

    self.config_publish_lock.synchronize do
      original_config = PublishedConfig.active_config
      config = original_config.deep_dup

      # Find the already published "lower" api backend, change its rate
      # limits, and republish.
      api = config["apis"].find { |a| a["name"] == "#{unique_test_class_id} - Lower" }
      assert_equal(3, api["settings"]["rate_limits"][0]["limit"])
      api["settings"]["rate_limits"][0]["limit"] = 80
      PublishedConfig.create!(:config => config).wait_until_live

      # Make sure any local worker cache is cleared across all possible
      # worker processes.
      responses = exercise_all_workers("/#{unique_test_class_id}/lower/info/", http_opts)
      responses.each do |resp|
        assert_equal("80", resp.headers["x-ratelimit-limit"])
      end
    ensure
      PublishedConfig.create!(:config => original_config).wait_until_live
    end

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/lower/info/", http_opts)
    assert_equal("3", response.headers["x-ratelimit-limit"])
  end
end
