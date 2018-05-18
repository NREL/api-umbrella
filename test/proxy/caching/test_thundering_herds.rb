require_relative "../../test_helper"

class Test::Proxy::Caching::TestThunderingHerds < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  def setup
    super
    setup_server
  end

  def test_connection_collapsing_for_cacheable
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => true,
    })
  end

  def test_connection_collapsing_for_cacheable_precache_fresh
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => true,
      :precache => true,
    })
  end

  def test_connection_collapsing_for_cacheable_precache_stale
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => true,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_connection_collapsing_for_cacheable_streaming
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => true,
    })
  end

  def test_connection_collapsing_for_cacheable_streaming_precache_fresh
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => true,
      :precache => true,
    })
  end

  def test_connection_collapsing_for_cacheable_streaming_precache_stale
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => true,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_connection_collapsing_for_public_cacheable
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => true,
    })
  end

  def test_connection_collapsing_for_public_cacheable_precache_fresh
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => true,
      :precache => true,
    })
  end

  def test_connection_collapsing_for_public_cacheable_precache_stale
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => true,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_connection_collapsing_for_public_cacheable_streaming
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => true,
    })
  end

  def test_connection_collapsing_for_public_cacheable_streaming_precache_fresh
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => true,
      :precache => true,
    })
  end

  def test_connection_collapsing_for_public_cacheable_streaming_precache_stale
    assert_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => true,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_no_connection_collapsing_for_private_cacheable
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
    })
  end

  def test_no_connection_collapsing_for_private_cacheable_precache_fresh
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
      :precache => true,
    })
  end

  def test_no_connection_collapsing_for_private_cacheable_precache_stale
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_no_connection_collapsing_for_private_cacheable_streaming
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
    })
  end

  def test_no_connection_collapsing_for_private_cacheable_streaming_precache_fresh
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
      :precache => true,
    })
  end

  def test_no_connection_collapsing_for_private_cacheable_streaming_precache_stale
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_no_connection_collapsing_for_cache_disabled
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
    })
  end

  def test_no_connection_collapsing_for_cache_disabled_precache_fresh
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
      :precache => true,
    })
  end

  def test_no_connection_collapsing_for_cache_disabled_precache_stale
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_no_connection_collapsing_for_cache_disabled_streaming
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
    })
  end

  def test_no_connection_collapsing_for_cache_disabled_streaming_precache_fresh
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
      :precache => true,
    })
  end

  def test_no_connection_collapsing_for_cache_disabled_streaming_precache_stale
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_no_connection_collapsing_for_no_explicit_cache
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
    })
  end

  def test_no_connection_collapsing_for_no_explicit_cache_precache_fresh
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
      :precache => true,
    })
  end

  def test_no_connection_collapsing_for_no_explicit_cache_precache_stale
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_no_connection_collapsing_for_no_explicit_cache_streaming
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
    })
  end

  def test_no_connection_collapsing_for_no_explicit_cache_streaming_precache_fresh
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
      :precache => true,
    })
  end

  def test_no_connection_collapsing_for_no_explicit_cache_streaming_precache_stale
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_no_connection_collapsing_for_non_cacheable
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
    })
  end

  def test_no_connection_collapsing_for_non_cacheable_precache_fresh
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
      :precache => true,
    })
  end

  def test_no_connection_collapsing_for_non_cacheable_precache_stale
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    }, {
      :cacheable => false,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  def test_no_connection_collapsing_for_non_cacheable_streaming
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
    })
  end

  def test_no_connection_collapsing_for_non_cacheable_streaming_precache_fresh
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
      :precache => true,
    })
  end

  def test_no_connection_collapsing_for_non_cacheable_streaming_precache_stale
    refute_connections_collapsed("/api/cacheable-thundering-herd/", {
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    }, {
      :cacheable => false,
      :precache => true,
      :precache_stale_delay => 6,
    })
  end

  private

  def make_thundering_herd_requests(path, custom_http_options = {}, options = {})
    http_opts = http_options.deep_merge(custom_http_options).deep_merge({
      :params => {
        :unique_test_id => unique_test_id,
      },
      :headers => {
        "X-Unique-ID" => SecureRandom.uuid,
      },
    })

    url = "http://127.0.0.1:9080#{path}/#{unique_test_id}"

    # Make an initial request if the cache is being pre-seeded.
    if(options[:precache])
      request = Typhoeus::Request.new(url, http_opts)
      request.run
    end

    # Wait until the cache expires if we're checking for the behavior of
    # cached, but stale items.
    if(options[:precache_stale_delay])
      sleep(options[:precache_stale_delay])
    end

    # Make the thundering herd of 50 concurrent requests.
    hydra = Typhoeus::Hydra.new
    requests = Array.new(50) do
      http_opts.deep_merge!({
        :headers => {
          "X-Unique-ID" => SecureRandom.uuid,
        },
      })
      request = Typhoeus::Request.new(url, http_opts)
      hydra.queue(request)
      request
    end
    hydra.run

    # Verify all responses were successful.
    assert_equal(50, requests.length)
    requests.each do |request|
      assert_response_code(200, request.response)
    end
  end

  def backend_call_count
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    response.body.to_i
  end

  def unique_response_bodies(requests)
    requests.map { |r| r.response.body }.uniq.length
  end

  def cache_status(requests)
    cache_status = {}
    requests.each do |request|
      cache = request.response.headers["X-Cache"]
      cache_status[cache] ||= 0
      cache_status[cache] += 1
    end
    cache_status
  end

  def request_timings(requests)
    requests.map { |r| r.response.total_time }.sort
  end

  def assert_connections_collapsed(path, custom_http_options = {}, options = {})
    requests = make_thundering_herd_requests(path, custom_http_options, options)

    # Since a thundering herd is prevented, ensure connection collapsing and
    # caching took place so that the API backend was only called once (plus 1
    # additional time when pre-caching is enabled for the initial request).
    if(options[:precache] && options[:precache_stale_delay])
      assert_equal(2, backend_call_count)
    else
      assert_equal(1, backend_call_count)
    end

    # Ensure all the responses back were identical, since the connections were
    # collapsed to a single API backend request and cached.
    assert_equal(1, unique_response_bodies(requests))

    # If there was a fresh cache item in place before making our thundering
    # herd of requests, then all responses should be cache hits. Otherwise, the
    # first request will be a cache miss, but the rest should be hits.
    if(options[:precache] && !options[:precache_stale_delay])
      assert_equal({
        "HIT" => 50,
      }, cache_status(requests))
    else
      assert_equal({
        "HIT" => 49,
        "MISS" => 1,
      }, cache_status(requests))
    end

    # Check the response times to ensure the connection collapsing behavior
    # doesn't serialize the requests and take too long for potentially
    # uncacheable responses (as TrafficServer's open read retry can do)
    timings = request_timings(requests)

    # For cacheable responses that have a fresh pre-cached hit, then all
    # responses should be cached and not subject to the API backend's delay.
    if(options.fetch(:cacheable) && options[:precache] && !options[:precache_stale_delay])
      assert_includes(0.0..0.5, timings.min)
      assert_includes(0.0..0.5, timings.max)

    # For cacheable responses, the response times should all be in the
    # neighborhood of the API backend's delayed response time (since after the
    # first request comes back, it should cached and used for all the pending
    # requests, so the pending requests respond basically instantly).
    elsif(options.fetch(:cacheable))
      assert_includes(1.9..2.5, timings.min)
      assert_includes(1.9..2.5, timings.max)

    # For non-cacheable responses, the response times for the parallel requests
    # might be double the initial response time at worst. This is because the
    # first response has to be received before the server knows it's
    # non-cacheable and then the rest of the pending, parallel requests should
    # all be sent at once (we just want to ensure it's no worse than 2x in the
    # worst case).
    else
      assert_includes(1.9..2.5, timings.min)
      assert_includes(3.9..4.5, timings.max)
    end
  end

  def refute_connections_collapsed(path, custom_http_options = {}, options = {})
    requests = make_thundering_herd_requests(path, custom_http_options, options)

    # Since a thundering herd is allowed, ensure the API backend was called for
    # each request made (since no caching or connection collapsing should have
    # happened). There's 1 additional request when pre-caching is enabled (for
    # the first pre-cached request).
    if(options[:precache])
      assert_equal(51, backend_call_count)
    else
      assert_equal(50, backend_call_count)
    end

    # Ensure each response back was unique, since no responses should be cached
    # or shared.
    assert_equal(50, unique_response_bodies(requests))

    # All responses back should have been a cache miss.
    assert_equal({
      "MISS" => 50,
    }, cache_status(requests))

    # Check the response times to ensure the connection collapsing behavior
    # doesn't serialize the requests and take too long for potentially
    # uncacheable responses (as TrafficServer's open read retry can do)
    timings = request_timings(requests)

    # For cacheable responses that have a fresh pre-cached hit, then all
    # responses should be cached and not subject to the API backend's delay.
    if(options.fetch(:cacheable) && options[:precache] && !options[:precache_stale_delay])
      assert_includes(0.0..0.5, timings.min)
      assert_includes(0.0..0.5, timings.max)

    # For non-cacheable responses that are streamed back (when the headers are
    # received back immediately, and then it's only the body that's delayed),
    # then all the requests should be parallelized immediately, so there should
    # be no significant delays.
    elsif(!options.fetch(:cacheable) && custom_http_options[:headers]["X-Delay-Before"] == "body")
      assert_includes(1.9..2.5, timings.min)
      assert_includes(1.9..2.5, timings.max)

    # For non-cacheable *requests* when TrafficServer knows immediately the
    # response won't be cacheable without actually receiving the response (eg,
    # POST requests), then all the requests should be parallelized immediately.
    elsif(!options.fetch(:cacheable) && custom_http_options[:method] == "POST")
      assert_includes(1.9..2.5, timings.min)
      assert_includes(1.9..2.5, timings.max)

    # For all other situations, the response times for the parallel requests
    # might be double the initial response time at worst. This is because the
    # first response has to be received before the server knows it's
    # non-cacheable and then the rest of the pending, parallel requests should
    # all be sent at once (we just want to ensure it's no worse than 2x in the
    # worst case).
    else
      assert_includes(1.9..2.5, timings.min)
      assert_includes(3.9..4.5, timings.max)
    end
  end
end
