require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestDistributedRateLimits < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::RateLimits
  include Minitest::Hooks

  def setup
    setup_server
    once_per_class_setup do
      override_config_set({
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
      }, "--router")

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
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }

    set_distributed_count_and_sync(143, options)
    assert_local_count("/api/hello", 143, options)
  end

  def test_increases_existing_rate_limits_to_match_distributed_value
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }.merge(frozen_time)

    make_requests_and_sync("/api/hello", 75, options)
    set_distributed_count_and_sync(99, options)
    assert_local_count("/api/hello", 99, options)
  end

  def test_ignores_distributed_value_when_lower
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }.merge(frozen_time)

    make_requests_and_sync("/api/hello", 80, options)
    set_distributed_count_and_sync(60, options)
    assert_local_count("/api/hello", 80, options)
  end

  def test_syncs_local_limits_into_mongo
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }

    make_requests_and_sync("/api/hello", 27, options)
    assert_distributed_count(27, options)
  end

  def test_sets_expected_rate_limit_record_after_requests
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }

    make_requests_and_sync("/api/hello", 27, options)
    assert_distributed_count(27, options)
    assert_distributed_count_record(options)
  end

  def test_sets_expected_rate_limit_record_when_set_from_tests
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }

    set_distributed_count_and_sync(143, options)
    assert_distributed_count_record(options)
  end

  def test_does_not_sync_non_distributed_limits
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1004,
    }

    make_requests_and_sync("/#{unique_test_class_id}/specific/hello/non-distributed/", 47, options)
    assert_distributed_count(0, options)
  end

  def test_syncs_api_specific_limits
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1002,
    }

    make_requests_and_sync("/#{unique_test_class_id}/specific/hello", 133, options)
    assert_distributed_count(133, options)
  end

  def test_syncs_api_specific_subsetting_limits
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1003,
    }

    make_requests_and_sync("/#{unique_test_class_id}/specific/hello/subsettings/", 38, options)
    assert_distributed_count(38, options)
  end

  def test_syncs_requests_in_past_within_bucket_time
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1005,
      :time => Time.now.utc - 8 * 60 * 60, # 8 hours ago
    }

    make_requests_and_sync("/#{unique_test_class_id}/specific/hello/long-duration-bucket/", 4, options)
    assert_distributed_count(4, options)
  end

  def test_does_not_sync_requests_in_past_outside_bucket_time
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1005,
      :time => Time.now.utc - 48 * 60 * 60, # 48 hours ago
    }

    make_requests_and_sync("/#{unique_test_class_id}/specific/hello/long-duration-bucket/", 3, options)
    assert_distributed_count(0, options)
  end

  def test_syncs_within_duration_on_reload_or_start
    self.config_set_mutex.synchronize do
      time = Time.now.utc
      options = {
        :api_key => FactoryGirl.create(:api_user).api_key,
        :duration => 50 * 60 * 1000, # 50 minutes
        :accuracy => 1 * 60 * 1000, # 1 minute
        :limit => 1001,
      }

      options[:time] = time - 40 * 60 # 40 minutes ago
      set_distributed_count_and_sync(3, options.merge(:skip_sync_wait => true))

      options[:time] = time - 45 * 60 # 45 minutes ago
      set_distributed_count_and_sync(97, options.merge(:skip_sync_wait => true))

      options[:time] = time - 51 * 60 # 51 minutes ago
      set_distributed_count_and_sync(41, options.merge(:skip_sync_wait => true))

      ApiUmbrellaTestHelpers::Process.reload("--router")

      options[:time] = time
      assert_local_count("/api/hello", 100, options)
    end
  end

  def test_polls_for_distributed_changes
    options = {
      :api_key => FactoryGirl.create(:api_user).api_key,
      :duration => 50 * 60 * 1000, # 50 minutes
      :accuracy => 1 * 60 * 1000, # 1 minute
      :limit => 1001,
    }.merge(frozen_time)

    make_requests_and_sync("/api/hello", 9, options)
    assert_distributed_count(9, options)
    assert_local_count("/api/hello", 9, options)

    make_requests_and_sync("/api/hello", 10, options.merge(:disable_count_check => true))
    # The expected count is 20 due to the extra request made in
    # assert_local_count (9 + 10 + 1).
    assert_distributed_count(20, options)
    assert_local_count("/api/hello", 20, options)

    # Delay the next override to give a chance for the request made in
    # assert_local_count above a chance to propagate so that we can override
    # it.
    sleep 0.55

    set_distributed_count_and_sync(77, options)
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

  def make_requests_and_sync(path, count, options = {})
    responses = make_requests(path, count, options.slice(:api_key, :time))

    unless(options[:disable_count_check])
      reported_requests_made = 0
      responses.each do |response|
        assert_equal(200, response.code, response.body)
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

    # Delay the callback to give the local rate limits (from the actual
    # requests being made) a chance to be pushed into the distributed mongo
    # store.
    sleep 0.55

    responses
  end

  def set_distributed_count_and_sync(count, options = {})
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

    # Delay the callback to give the distributed rate limit a chance to
    # propagate to the local nodes.
    sleep 0.55 unless(options[:skip_sync_wait])
  end

  def assert_distributed_count(expected_count, options = {})
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
          :_id => "$_id",
          :count => { "$sum" => "$count" },
        },
      },
    ])

    count = 0
    if(results && results.first && results.first["count"])
      count = results.first["count"]
    end

    assert_equal(expected_count, count)
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
    response = make_requests(path, 1, options.slice(:api_key, :time)).first
    assert_equal(200, response.code, response.body)
    assert_equal(options.fetch(:limit), response.headers["x-ratelimit-limit"].to_i)

    count = options.fetch(:limit) - response.headers["x-ratelimit-remaining"].to_i
    count_before_request = count - 1
    assert_equal(expected_count, count_before_request)
  end
end
