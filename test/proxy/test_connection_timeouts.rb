require_relative "../test_helper"

class Test::Proxy::TestConnectionTimeouts < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::RequestBodyStreaming

  # While these tests can be parallelized, given the timing sensitivities of
  # them, we will not parallelize them to cut down on flaky tests due to the
  # timings being skewed by other activity.
  # parallelize_me!

  BUFFER_TIME_LOWER = 0.15
  BUFFER_TIME_UPPER = 1.5

  def setup
    super
    setup_server
  end

  def test_quick_timeout_when_backends_down
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9450 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/down", :backend_prefix => "/down" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/down", http_options)

      assert_response_code(503, response)
      assert_operator(response.total_time, :<, 1)
    end
  end

  # We test to ensure slow-responding responses do not hit the connection
  # timeout. Connection timeouts should only be hit in the event the connection
  # itself is slow to respond, but that's hard to test against (since the
  # underlying server in these cases is up). So for now, we're just going to
  # assume connection timeouts work as expected.
  def test_connect_timeout_get
    connect_timeout = $config["nginx"]["proxy_connect_timeout"]
    read_timeout = $config["nginx"]["proxy_read_timeout"]
    delay = connect_timeout + 2
    assert_operator(delay, :<, read_timeout)

    response = Typhoeus.get("http://127.0.0.1:9080/api/delay-sec/#{delay}", http_options)
    assert_response_code(200, response)
    assert_operator(response.total_time, :>, connect_timeout - BUFFER_TIME_LOWER)
  end

  def test_connect_timeout_post
    connect_timeout = $config["nginx"]["proxy_connect_timeout"]
    read_timeout = $config["nginx"]["proxy_read_timeout"]
    delay = connect_timeout + 2
    assert_operator(delay, :<, read_timeout)

    response = Typhoeus.post("http://127.0.0.1:9080/api/delay-sec/#{delay}", http_options)
    assert_response_code(200, response)
    assert_operator(response.total_time, :>, connect_timeout - BUFFER_TIME_LOWER)
  end

  def test_response_begins_within_read_timeout
    delay1 = $config["nginx"]["proxy_read_timeout"] - 2
    delay2 = $config["nginx"]["proxy_read_timeout"] + 2
    assert_operator(delay1, :>, 0)
    assert_operator(delay2, :>, 0)
    assert_operator(delay2 - delay1, :>, 0)
    assert_operator(delay2 - delay1, :<, $config["nginx"]["proxy_read_timeout"])

    response = Typhoeus.post("http://127.0.0.1:9080/api/delays-sec/#{delay1}/#{delay2}", http_options)
    assert_response_code(200, response)
    assert_equal("firstdone", response.body)
    assert_operator(response.total_time, :>=, delay2 - BUFFER_TIME_LOWER)
    assert_operator(response.total_time, :<=, delay2 + BUFFER_TIME_UPPER)
  end

  def test_response_sends_chunks_at_least_once_per_read_timeout_interval
    delay1 = 1
    delay2 = $config["nginx"]["proxy_read_timeout"]
    assert_operator(delay1, :>, 0)
    assert_operator(delay2, :>, 0)
    assert_operator(delay2 - delay1, :>, 0)
    assert_operator(delay2 - delay1, :<, $config["nginx"]["proxy_read_timeout"])

    response = Typhoeus.post("http://127.0.0.1:9080/api/delays-sec/#{delay1}/#{delay2}", http_options)
    assert_response_code(200, response)
    assert_equal("firstdone", response.body)
    assert_operator(response.total_time, :>=, delay2 - BUFFER_TIME_LOWER)
    assert_operator(response.total_time, :<=, delay2 + BUFFER_TIME_UPPER)
  end

  def test_response_closes_when_chunk_delay_exceeds_read_timeout
    delay1 = 1
    delay2 = $config["nginx"]["proxy_read_timeout"] + 2
    assert_operator(delay1, :>, 0)
    assert_operator(delay2, :>, 0)
    assert_operator(delay2 - delay1, :>, 0)
    assert_operator(delay2 - delay1, :>, $config["nginx"]["proxy_read_timeout"])

    response = Typhoeus.post("http://127.0.0.1:9080/api/delays-sec/#{delay1}/#{delay2}", http_options)
    assert_response_code(200, response)
    assert_equal("first", response.body)
    assert_operator(response.total_time, :>=, delay1 + $config["nginx"]["proxy_read_timeout"] - BUFFER_TIME_LOWER)
    assert_operator(response.total_time, :<=, delay1 + $config["nginx"]["proxy_read_timeout"] + BUFFER_TIME_UPPER)
  end

  def test_request_begins_within_send_timeout
    delay1 = $config["nginx"]["proxy_send_timeout"] - 2
    delay2 = $config["nginx"]["proxy_send_timeout"] + 2
    assert_operator(delay1, :>, 0)
    assert_operator(delay2, :>, 0)
    assert_operator(delay2 - delay1, :>, 0)
    assert_operator(delay2 - delay1, :<, $config["nginx"]["proxy_send_timeout"])

    easy = make_streaming_body_request([
      {
        :data => "foo",
        :sleep => delay1,
      },
      {
        :data => "bar",
        :sleep => delay2 - delay1,
      },
    ])

    assert_equal(200, easy.response_code)
    data = MultiJson.load(easy.response_body)
    assert_equal(["foo", "bar"], data.fetch("chunks"))
    assert_equal(2, data.fetch("chunk_time_gaps").length)
    assert_in_delta(delay1, data.fetch("chunk_time_gaps")[0], 0.3)
    assert_in_delta(delay2 - delay1, data.fetch("chunk_time_gaps")[1], 0.3)
    assert_operator(easy.total_time, :>=, delay2 - BUFFER_TIME_LOWER)
    assert_operator(easy.total_time, :<=, delay2 + BUFFER_TIME_UPPER)
  end

  def test_request_sends_chunks_at_least_once_per_send_timeout_interval
    delay1 = 1
    delay2 = $config["nginx"]["proxy_send_timeout"]
    assert_operator(delay1, :>, 0)
    assert_operator(delay2, :>, 0)
    assert_operator(delay2 - delay1, :>, 0)
    assert_operator(delay2 - delay1, :<, $config["nginx"]["proxy_send_timeout"])

    easy = make_streaming_body_request([
      {
        :data => "foo",
        :sleep => delay1,
      },
      {
        :data => "bar",
        :sleep => delay2 - delay1,
      },
    ])

    assert_equal(200, easy.response_code)
    data = MultiJson.load(easy.response_body)
    assert_equal(["foo", "bar"], data.fetch("chunks"))
    assert_equal(2, data.fetch("chunk_time_gaps").length)
    assert_in_delta(delay1, data.fetch("chunk_time_gaps")[0], 0.3)
    assert_in_delta(delay2 - delay1, data.fetch("chunk_time_gaps")[1], 0.3)
    assert_operator(easy.total_time, :>=, delay2 - BUFFER_TIME_LOWER)
    assert_operator(easy.total_time, :<=, delay2 + BUFFER_TIME_UPPER)
  end

  def test_request_closes_when_chunk_delay_exceeds_send_timeout
    delay1 = 1
    delay2 = $config["nginx"]["proxy_send_timeout"] + 2
    assert_operator(delay1, :>, 0)
    assert_operator(delay2, :>, 0)
    assert_operator(delay2 - delay1, :>, 0)
    assert_operator(delay2 - delay1, :>, $config["nginx"]["proxy_send_timeout"])

    easy = make_streaming_body_request([
      {
        :data => "foo",
        :sleep => delay1,
      },
      {
        :data => "bar",
        :sleep => delay2 - delay1,
      },
    ])

    assert_equal(408, easy.response_code)
    assert_match("Inactivity Timeout", easy.response_body)
    assert_operator(easy.total_time, :>=, delay1 + $config["nginx"]["proxy_send_timeout"] - BUFFER_TIME_LOWER)
    assert_operator(easy.total_time, :<=, delay1 + $config["nginx"]["proxy_send_timeout"] + BUFFER_TIME_UPPER)
  end

  # This is mainly done to ensure that any connection collapsing the cache is
  # doing, doesn't improperly hold up non-cacheable requests waiting on a
  # potentially cacheable request.
  def test_concurrent_requests_to_same_url_different_http_method
    delay = $config["nginx"]["proxy_read_timeout"] - 1
    assert_operator(delay, :>, 0)

    start_time = Time.now.utc

    get_thread = Thread.new do
      Thread.current[:response] = Typhoeus.get("http://127.0.0.1:9080/api/delay-sec/#{delay}", http_options)
    end

    # Wait 1 second to ensure the first GET request is fully established to the
    # backend.
    sleep 1

    post_thread = Thread.new do
      Thread.current[:response] = Typhoeus.post("http://127.0.0.1:9080/api/delay-sec/#{delay}", http_options)
    end

    get_thread.join
    post_thread.join
    total_time = Time.now.utc - start_time

    assert_response_code(200, get_thread[:response])
    assert_response_code(200, post_thread[:response])

    # Sanity check to ensure the 2 requests were made in parallel and
    # overlapped.
    assert_operator(get_thread[:response].total_time, :>=, delay - BUFFER_TIME_LOWER)
    assert_operator(get_thread[:response].total_time, :<, delay + BUFFER_TIME_UPPER)
    assert_operator(post_thread[:response].total_time, :>=, delay - BUFFER_TIME_LOWER)
    assert_operator(post_thread[:response].total_time, :<, delay + BUFFER_TIME_UPPER)
    assert_operator(total_time, :>=, delay + 1 - BUFFER_TIME_LOWER)
    assert_operator(total_time, :<, delay + (BUFFER_TIME_UPPER * 2))
    assert_operator(total_time, :<, (delay * 2) - 1)
  end

  # This is to ensure that no proxy in front of the backend makes multiple
  # retry attempts when a request times out (since we don't want to duplicate
  # requests if a backend is already struggling).
  def test_no_request_retry_get
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=get-timeout")
    assert_response_code(200, response)
    assert_equal("0", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/delay-sec/20?backend_counter_id=get-timeout", http_options)
    assert_response_code(504, response)
    assert_match("Inactivity Timeout", response.body)

    # Ensure that the backend has only been called once.
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=get-timeout")
    assert_response_code(200, response)
    assert_equal("1", response.body)

    # Wait 5 seconds for any possible retry attempts that might be pending, and
    # then ensure the backend has still only been called once.
    sleep 5
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=get-timeout")
    assert_response_code(200, response)
    assert_equal("1", response.body)
  end

  # Same test as above, but ensure non-GET requests are behaving the same (no
  # retry allowed). This is probably even more important for non-GET requests
  # since duplicating POST requests could be harmful (multiple creates,
  # updates, etc).
  def test_no_request_retry_post
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    assert_equal("0", response.body)

    response = Typhoeus.post("http://127.0.0.1:9080/api/delay-sec/20?backend_counter_id=#{unique_test_id}", http_options)
    assert_response_code(504, response)
    assert_match("Inactivity Timeout", response.body)

    # Ensure that the backend has only been called once.
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    assert_equal("1", response.body)

    # Wait 5 seconds for any possible retry attempts that might be pending, and
    # then ensure the backend has still only been called once.
    sleep 5
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    assert_equal("1", response.body)
  end

  # Since we have slightly different timeouts at the different layers (nginx vs
  # Trafficserver), ensure there's no retries or other odd behavior when the
  # response times are right around the timeout length.
  def test_no_request_retry_when_timeout_between_layer_timeouts
    start_delay = $config["nginx"]["proxy_connect_timeout"] - 1
    end_delay = $config["nginx"]["proxy_read_timeout"] * 2
    assert_operator(start_delay, :>, 0)
    assert_operator(start_delay, :<, end_delay)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    assert_equal("0", response.body)

    hydra = Typhoeus::Hydra.new
    requests = []
    delay = start_delay
    while delay <= end_delay
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/delay-sec/#{delay}?backend_counter_id=#{unique_test_id}", http_options)
      hydra.queue(request)

      requests << {
        :request => request,
        :delay => delay,
      }

      delay += 0.5
    end
    hydra.run

    requests.each do |req|
      if req.fetch(:delay) >= $config["nginx"]["proxy_read_timeout"] + 1
        assert_response_code(504, req.fetch(:request).response)
        assert_match("Inactivity Timeout", req.fetch(:request).response.body)
      elsif req.fetch(:delay) < $config["nginx"]["proxy_read_timeout"]
        assert_response_code(200, req.fetch(:request).response)
      end
    end

    # Ensure that the backend has only been called once for each test.
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    assert_equal(requests.length.to_s, response.body)

    # Wait 5 seconds for any possible retry attempts that might be pending, and
    # then ensure the backend has still only been called once.
    sleep 5
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    assert_equal(requests.length.to_s, response.body)
  end

  # This is to check the behavior of Trafficserver's
  # "proxy.config.http.down_server.cache_time" configuration, to ensure a bunch
  # of backend timeouts don't remove all the servers from rotation.
  def test_backend_remains_in_rotation_after_timeouts
    timeout_hydra = Typhoeus::Hydra.new
    timeout_requests = Array.new(50) do
      delay = $config["nginx"]["proxy_read_timeout"] + 2
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/delay-sec/#{delay}", http_options)
      timeout_hydra.queue(request)
      request
    end
    timeout_hydra.run

    info_hydra = Typhoeus::Hydra.new
    info_requests = Array.new(50) do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/info/", http_options)
      info_hydra.queue(request)
      request
    end
    info_hydra.run

    assert_equal(50, timeout_requests.length)
    timeout_requests.each do |request|
      assert_response_code(504, request.response)
      assert_match("Inactivity Timeout", request.response.body)
    end

    assert_equal(50, info_requests.length)
    info_requests.each do |request|
      assert_response_code(200, request.response)
    end
  end
end
