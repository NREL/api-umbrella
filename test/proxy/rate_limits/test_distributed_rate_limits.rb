require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestDistributedRateLimits < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::RateLimits
  include Minitest::Hooks

  def setup
    super
    setup_server
    @override_config = {
      :apiSettings => {
        :rate_limits => [
          {
            :duration => 50 * 60 * 1000, # 50 minutes
            :accuracy => 1 * 60 * 1000, # 1 minute
            :limit_by => "apiKey",
            :limit => 1001,
            :distributed => true,
            :response_headers => true,
          },
        ],
      },
    }
    once_per_class_setup do
      override_config_set(@override_config, "--router")

      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/specific/", :backend_prefix => "/" }],
          :settings => {
            :rate_limits => [
              {
                :duration => 45 * 60 * 1000, # 45 minutes
                :accuracy => 1 * 60 * 1000, # 1 minute
                :limit_by => "apiKey",
                :limit => 1002,
                :distributed => true,
                :response_headers => true,
              },
            ],
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/hello/subsettings/",
              :settings => {
                :rate_limits => [
                  {
                    :duration => 48 * 60 * 1000, # 48 minutes
                    :accuracy => 1 * 60 * 1000, # 1 minute
                    :limit_by => "apiKey",
                    :limit => 1003,
                    :distributed => true,
                    :response_headers => true,
                  },
                ],
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/non-distributed/",
              :settings => {
                :rate_limits => [
                  {
                    :duration => 12 * 60 * 1000, # 12 minutes
                    :accuracy => 1 * 60 * 1000, # 1 minute
                    :limit_by => "apiKey",
                    :limit => 1004,
                    :distributed => false,
                    :response_headers => true,
                  },
                ],
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/long-duration-bucket/",
              :settings => {
                :rate_limits => [
                  {
                    :duration => 24 * 60 * 60 * 1000, # 1 day
                    :accuracy => 60 * 60 * 1000, # 1 hour
                    :limit_by => "apiKey",
                    :limit => 1005,
                    :distributed => true,
                    :response_headers => true,
                  },
                ],
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/short-duration-bucket/",
              :settings => {
                :rate_limits => [
                  {
                    :duration => 1 * 60 * 1000, # 1 minute
                    :accuracy => 5 * 1000, # 5 seconds
                    :limit_by => "apiKey",
                    :limit => 1006,
                    :distributed => true,
                    :response_headers => true,
                  },
                ],
              },
            },
          ],
        },
      ])
    end
  end

  def after_all
    super
    override_config_reset("--router")
  end

  def test_sets_new_limits_to_distributed_value
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }

    set_distributed_count(143, options)
    assert_local_count("/api/hello", 143, options)
  end

  def test_increases_existing_rate_limits_to_match_distributed_value
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }.merge(frozen_time)

    responses = make_requests("/api/hello", 75, options)
    assert_response_headers(75, responses, options)
    assert_distributed_count(75, options)
    set_distributed_count(99, options)
    assert_local_count("/api/hello", 99, options)
  end

  def test_ignores_distributed_value_when_lower
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }.merge(frozen_time)

    responses = make_requests("/api/hello", 80, options)
    assert_response_headers(80, responses, options)
    set_distributed_count(60, options)
    assert_local_count("/api/hello", 80, options)
  end

  def test_syncs_local_limits_into_mongo
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }

    responses = make_requests("/api/hello", 27, options)
    assert_response_headers(27, responses, options)
    assert_distributed_count(27, options)
  end

  def test_sets_expected_rate_limit_record_after_requests
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }

    responses = make_requests("/api/hello", 27, options)
    assert_response_headers(27, responses, options)
    assert_distributed_count(27, options)
    assert_distributed_count_record(options)
  end

  def test_sets_expected_rate_limit_record_when_set_from_tests
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }

    set_distributed_count(143, options)
    assert_distributed_count_record(options)
  end

  def test_does_not_sync_non_distributed_limits
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1004,
    }

    responses = make_requests("/#{unique_test_class_id}/specific/hello/non-distributed/", 47, options)
    assert_response_headers(47, responses, options)
    assert_distributed_count(0, options)
  end

  def test_syncs_api_specific_limits
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1002,
    }

    responses = make_requests("/#{unique_test_class_id}/specific/hello", 133, options)
    assert_response_headers(133, responses, options)
    assert_distributed_count(133, options)
  end

  # A short duration bucket test (where the accuracy bucket is 5 seconds) helps
  # uncover issues when the requests are split across multiple buckets. While
  # still not guaranteed, we're more likely to hit requests being split across
  # a 5 second boundary, than a 1 minute boundary.
  def test_syncs_short_duration_buckets
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 1 * 60 * 1000, # 1 minute
      :accuracy => 5 * 1000, # 5 seconds
      :limit => 1006,
    }

    responses = make_requests("/#{unique_test_class_id}/specific/hello/short-duration-bucket/", 150, options)
    assert_response_headers(150, responses, options)
    assert_distributed_count(150, options)
  end

  def test_syncs_api_specific_subsetting_limits
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1003,
    }

    responses = make_requests("/#{unique_test_class_id}/specific/hello/subsettings/", 38, options)
    assert_response_headers(38, responses, options)
    assert_distributed_count(38, options)
  end

  def test_syncs_requests_in_past_within_bucket_time
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1005,
      :time => Time.now.utc - 8 * 60 * 60, # 8 hours ago
    }

    responses = make_requests("/#{unique_test_class_id}/specific/hello/long-duration-bucket/", 4, options)
    assert_response_headers(4, responses, options)
    assert_distributed_count(4, options)
  end

  def test_does_not_sync_requests_in_past_outside_bucket_time
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1005,
      :time => Time.now.utc - 48 * 60 * 60, # 48 hours ago
    }

    responses = make_requests("/#{unique_test_class_id}/specific/hello/long-duration-bucket/", 3, options)
    assert_response_headers(3, responses, options)
    assert_distributed_count(0, options)
  end

  def test_syncs_within_duration_on_reload_or_start
    time = Time.now.utc
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }

    options[:time] = time - 40 * 60 # 40 minutes ago
    set_distributed_count(3, options)

    options[:time] = time - 45 * 60 # 45 minutes ago
    set_distributed_count(97, options)

    options[:time] = time - 51 * 60 # 51 minutes ago
    set_distributed_count(41, options)

    # Trigger an nginx reload by setting new configuration. While we're not
    # technically changing the configuration, setting the config gives us an
    # easier way to wait until the nginx processes have fully reloaded before
    # proceeding (so this test doesn't interfere with other tests).
    override_config_set(@override_config, "--router") do
      options[:time] = time
      assert_local_count("/api/hello", 100, options)
    end
  end

  def test_polls_for_distributed_changes
    options = {
      :api_key => FactoryBot.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }.merge(frozen_time)

    responses = make_requests("/api/hello", 10, options)
    assert_response_headers(10, responses, options)
    assert_distributed_count(10, options)
    assert_local_count("/api/hello", 10, options)

    responses = make_requests("/api/hello", 10, options)
    assert_response_headers(20, responses, options)
    assert_distributed_count(20, options)
    assert_local_count("/api/hello", 20, options)

    set_distributed_count(77, options)
    assert_distributed_count(77, options)
    assert_local_count("/api/hello", 77, options)
  end

  private

  def frozen_time
    # Freeze the time to ensure that the make_requests and
    # set_distributed_count calls both affect the same bucket (otherwise,
    # make_requests could end up populating two buckets if these tests happen
    # to run across a minute boundary).
    {
      :time => Time.now.utc,
    }
  end

  def assert_response_headers(count, responses, options = {})
    reported_requests_made = 0
    responses.each do |response|
      assert_response_code(200, response)
      assert_equal(options.fetch(:limit).to_s, response.headers["x-ratelimit-limit"])
      assert(response.headers["x-ratelimit-remaining"])
      reported_count = response.headers["x-ratelimit-limit"].to_i - response.headers["x-ratelimit-remaining"].to_i
      if(reported_count > reported_requests_made)
        reported_requests_made = reported_count
      end
    end

    assert_operator(reported_requests_made, :>=, count - 1)
    assert_operator(reported_requests_made, :<=, count)

    # In some rare situations our internal rate limit counters might be off
    # since we fetch all of our rate limits and then increment them separately.
    # The majority of race conditions should be solved, but one known issue
    # remains that may very rarely lead to this warning (but we don't want to
    # fail the whole test as long as it remains rare). See comments in
    # rate_limit.lua's increment_all_limits().
    if(reported_requests_made != count)
      puts "WARNING: X-RateLimit-Remaining header was off by 1. This should be very rare. Investigate if you see this with any regularity."
    end
  end

  def set_distributed_count(count, options = {})
    time = options[:time] || Time.now.utc
    bucket_start_time = ((time.to_f * 1000) / options.fetch(:accuracy)).floor * options.fetch(:accuracy)
    host = options[:host] || "127.0.0.1"
    key = "apiKey:#{options.fetch(:duration)}:#{options.fetch(:api_key)}:#{host}:#{bucket_start_time}"

    db = Mongoid.client(:default)
    db[:rate_limits].update_one({ :_id => key }, {
      "$currentDate" => {
        "ts" => { "$type" => "timestamp" },
      },
      "$set" => {
        :count => count,
      },
      "$setOnInsert" => {
        :expire_at => Time.at((bucket_start_time + options.fetch(:duration) + 60000) / 1000.0).utc,
      },
    }, :upsert => true)
  end

  def assert_distributed_count(expected_count, options = {})
    # Wait until the distributed count is synced and matches the expected
    # value. Normally this should happen very quickly, but allow some amount
    # of buffer.
    results = nil
    count = nil
    Timeout.timeout(5) do
      loop do
        db = Mongoid.client(:default)
        results = db[:rate_limits].aggregate([
          {
            "$match" => {
              :_id => /:#{options.fetch(:api_key)}:/,
              :expire_at => { "$gte" => Time.now.utc },
            },
          },
          {
            "$group" => {
              :_id => nil,
              :count => { "$sum" => "$count" },
            },
          },
        ])

        count = 0
        if(results && results.first && results.first["count"])
          count = results.first["count"]
        end

        if(count == expected_count)
          assert_equal(expected_count, count)
          break
        end

        sleep 0.1
      end
    end
  rescue Timeout::Error
    flunk("Distributed count does not match expected value after timeout. Expected: #{expected_count.inspect} Last count: #{count.inspect} Last result: #{results.to_a.inspect if(results)}")
  end

  def assert_distributed_count_record(options)
    db = Mongoid.client(:default)
    record = db[:rate_limits].find(:_id => /:#{options.fetch(:api_key)}:/).sort(:ts => -1).limit(1).first
    assert_equal([
      "_id",
      "count",
      "expire_at",
      "ts",
    ].sort, record.keys.sort)
    assert_kind_of(String, record["_id"])
    assert_kind_of(Numeric, record["count"])
    assert_kind_of(Time, record["expire_at"])
    assert_kind_of(BSON::Timestamp, record["ts"])
  end

  def assert_local_count(path, expected_count, options = {})
    # Wait until the local count is synced and matches the expected value.
    # Normally this should happen very quickly, but allow some amount of
    # buffer.
    response = nil
    count = nil
    Timeout.timeout(5) do
      loop do
        request_options = options.slice(:api_key, :time).deep_merge({
          :http_options => {
            :headers => {
              # Use this header as a way to fetch the rate limits from the
              # proxy (returned in the headers) without actually incrementing
              # the number of requests made. This option is only available
              # when running in the test environment.
              "X-Api-Umbrella-Test-Skip-Increment-Limits" => "true",
            },
          },
        })
        response = make_requests(path, 1, request_options).first
        assert_response_code(200, response)
        assert_equal(options.fetch(:limit), response.headers["x-ratelimit-limit"].to_i)

        count = options.fetch(:limit) - response.headers["x-ratelimit-remaining"].to_i
        if(count == expected_count)
          assert_equal(expected_count, count)
          break
        end

        sleep 0.1
      end
    end
  rescue Timeout::Error
    flunk("Local count does not match expected value after timeout. Expected: #{expected_count.inspect} Last count: #{count.inspect} Last response: #{response}")
  end
end
