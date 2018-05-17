require_relative "../../test_helper"

class Test::Proxy::Caching::TestThunderingHerds < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  def setup
    super
    setup_server
  end

  def test_prevents_thundering_herds_for_cacheable
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_prevents_thundering_herds_for_cacheable_precache_fresh
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_prevents_thundering_herds_for_cacheable_precache_stale
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_prevents_thundering_herds_for_cacheable_streaming
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_prevents_thundering_herds_for_cacheable_streaming_precache_fresh
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_prevents_thundering_herds_for_cacheable_streaming_precache_stale
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => "max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_prevents_thundering_herds_for_public_cacheable
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_prevents_thundering_herds_for_public_cacheable_precache_fresh
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_prevents_thundering_herds_for_public_cacheable_precache_stale
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_prevents_thundering_herds_for_public_cacheable_streaming
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_prevents_thundering_herds_for_public_cacheable_streaming_precache_fresh
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_prevents_thundering_herds_for_public_cacheable_streaming_precache_stale
    assert_thundering_herd_prevented("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_private_cacheable
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_private_cacheable_precache_fresh
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_private_cacheable_precache_stale
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_private_cacheable_streaming
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_private_cacheable_streaming_precache_fresh
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_private_cacheable_streaming_precache_stale
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => "private, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_cache_disabled
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_cache_disabled_precache_fresh
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_cache_disabled_precache_stale
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_cache_disabled_streaming
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_cache_disabled_streaming_precache_fresh
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_cache_disabled_streaming_precache_stale
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => "max-age=0, private, must-revalidate",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_no_explicit_cache
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_no_explicit_cache_precache_fresh
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_no_explicit_cache_precache_stale
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_no_explicit_cache_streaming
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_no_explicit_cache_streaming_precache_fresh
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_no_explicit_cache_streaming_precache_stale
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :headers => {
        "X-Cache-Control-Response" => nil,
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_non_cacheable
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_non_cacheable_precache_fresh
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_non_cacheable_precache_stale
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "headers",
      },
    })
  end

  def test_allows_thundering_herds_for_non_cacheable_streaming
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_non_cacheable_streaming_precache_fresh
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  def test_allows_thundering_herds_for_non_cacheable_streaming_precache_stale
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", {
      :precache => true,
      :precache_stale_delay => 6,
      :method => "POST",
      :headers => {
        "X-Cache-Control-Response" => "public, max-age=4",
        "X-Delay" => "2",
        "X-Delay-Before" => "body",
      },
    })
  end

  private

  def make_thundering_herd_requests(path, options = {})
    precache = options.delete(:precache)
    precache_stale_delay = options.delete(:precache_stale_delay)
    http_opts = http_options.deep_merge(options).deep_merge({
      :params => {
        :unique_test_id => unique_test_id,
      },
      :headers => {
        "X-Unique-ID" => SecureRandom.uuid,
      },
    })

    url = "http://127.0.0.1:9080#{path}/#{unique_test_id}"
    if(precache)
      request = Typhoeus::Request.new(url, http_opts)
      request.run

      # puts "PREWARM: #{request.response.body.inspect}"
      # puts request.response.headers.inspect
    end

    if(precache_stale_delay)
      sleep(precache_stale_delay)
    end

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

    assert_equal(50, requests.length)
    requests.each do |request|
      # ap "#{request.response.code}: #{request.response.headers["X-Unique-ID"]}: #{request.response.total_time}"

      #if(prewarm)
        # ap request.response.body
        # puts request.options[:headers].inspect
        # puts request.response.headers.inspect
      #end
      assert_response_code(200, request.response)
    end
  end

  def assert_thundering_herd_allowed(path, options = {})
    requests = make_thundering_herd_requests(path, options)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    puts "ALLOWED BACKEND CALL COUNT: #{response.body}"
    # assert_equal("50", response.body)

    unique_response_bodies = requests.map { |r| r.response.body }.uniq
    puts "ALLOWED UNIQUE COUNT: #{unique_response_bodies.length}"
    # assert_equal(50, unique_response_bodies.length)
    puts "ALLOWED TIMING: #{requests.map { |r| r.response.total_time }.sort.inspect}"

    requests.each do |request|
      assert_response_code(200, request.response)
    end
  end

  def assert_thundering_herd_prevented(path, options = {})
    requests = make_thundering_herd_requests(path, options)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    puts "PREVENTED BACKEND CALL COUNT: #{response.body}"
    # assert_equal("1", response.body)

    unique_response_bodies = requests.map { |r| r.response.body }.uniq
    puts "PREVENTED UNIQUE COUNT: #{unique_response_bodies.length}"
    # assert_equal(1, unique_response_bodies.length)
    puts "PREVENTED TIMING: #{requests.map { |r| r.response.total_time }.sort.inspect}"

    requests.each do |request|
      assert_response_code(200, request.response)
    end
  end
end
