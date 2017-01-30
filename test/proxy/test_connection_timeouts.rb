require_relative "../test_helper"

class Test::Proxy::TestConnectionTimeouts < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

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

      assert_response_code(502, response)
      assert_operator(response.total_time, :<, 1)
    end
  end

  def test_connect_timeout_get
    timeout = $config["nginx"]["proxy_connect_timeout"]
    delay = timeout + 5
    response = Typhoeus.get("http://127.0.0.1:9080/api/delay-sec/#{delay}", http_options)

    assert_response_code(504, response)
    assert_operator(response.total_time, :>, timeout)
    assert_operator(response.total_time, :<, delay)
  end

  def test_connect_timeout_post
    timeout = $config["nginx"]["proxy_connect_timeout"]
    delay = timeout + 5
    response = Typhoeus.post("http://127.0.0.1:9080/api/delay-sec/#{delay}", http_options)

    assert_response_code(504, response)
    assert_operator(response.total_time, :>, timeout)
    assert_operator(response.total_time, :<, delay)
  end

  def test_response_begins_within_read_timeout
    delay1 = $config["nginx"]["proxy_read_timeout"] - 2
    delay2 = $config["nginx"]["proxy_connect_timeout"] + 5
    response = Typhoeus.post("http://127.0.0.1:9080/api/delays-sec/#{delay1}/#{delay2}", http_options)

    assert_response_code(200, response)
    assert_equal("firstdone", response.body)
  end

  def test_response_sends_chunks_at_least_once_per_read_timeout_interval
    delay1 = $config["nginx"]["proxy_read_timeout"] - 8
    delay2 = $config["nginx"]["proxy_read_timeout"]
    response = Typhoeus.post("http://127.0.0.1:9080/api/delays-sec/#{delay1}/#{delay2}", http_options)

    assert_response_code(200, response)
    assert_equal("firstdone", response.body)
  end

  def test_response_closes_when_chunk_delay_exceeds_read_timeout
    delay1 = $config["nginx"]["proxy_read_timeout"] - 8
    delay2 = $config["nginx"]["proxy_read_timeout"] + 4
    response = Typhoeus.post("http://127.0.0.1:9080/api/delays-sec/#{delay1}/#{delay2}", http_options)

    assert_response_code(200, response)
    assert_equal("first", response.body)
  end

  # This is mainly done to ensure that any connection collapsing the cache is
  # doing, doesn't improperly hold up non-cacheable requests waiting on a
  # potentially cacheable request.
  def test_concurrent_requests_to_same_url_different_http_method
    start_time = Time.now.utc

    get_thread = Thread.new do
      Thread.current[:response] = Typhoeus.get("http://127.0.0.1:9080/api/delay-sec/5", http_options)
    end

    # Wait 1 second to ensure the first GET request is fully established to the
    # backend.
    sleep 1

    post_thread = Thread.new do
      Thread.current[:response] = Typhoeus.post("http://127.0.0.1:9080/api/delay-sec/5", http_options)
    end

    get_thread.join
    post_thread.join
    total_time = Time.now.utc - start_time

    assert_equal(200, get_thread[:response].code)
    assert_equal(200, post_thread[:response].code)

    # Sanity check to ensure the 2 requests were made in parallel and
    # overlapped.
    assert_operator(total_time, :>, 5)
    assert_operator(total_time, :<, 9)
  end

  # This is to ensure that no proxy in front of the backend makes multiple
  # retry attempts when a request times out (since we don't want to duplicate
  # requests if a backend is already struggling).
  def test_no_request_retry_get
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=get-timeout")
    assert_response_code(200, response)
    assert_equal("0", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/timeout", http_options)
    assert_response_code(504, response)

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
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=post-timeout")
    assert_response_code(200, response)
    assert_equal("0", response.body)

    response = Typhoeus.post("http://127.0.0.1:9080/api/timeout", http_options)
    assert_response_code(504, response)

    # Ensure that the backend has only been called once.
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=post-timeout")
    assert_response_code(200, response)
    assert_equal("1", response.body)

    # Wait 5 seconds for any possible retry attempts that might be pending, and
    # then ensure the backend has still only been called once.
    sleep 5
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=post-timeout")
    assert_response_code(200, response)
    assert_equal("1", response.body)
  end

  # Since we have to workaround Varnish's double request issue by setting it's
  # timeout longer than nginx's, just ensure everything still works when
  # something times according to nginx's timeout, but not varnish's longer
  # timeout.
  def test_no_request_retry_when_timeout_between_varnish_and_nginx_timeout
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=post-between-varnish-timeout")
    assert_response_code(200, response)
    assert_equal("0", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/between-varnish-timeout", http_options)
    assert_response_code(504, response)

    # Ensure that the backend has only been called once.
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=post-between-varnish-timeout")
    assert_response_code(200, response)
    assert_equal("1", response.body)

    # Wait 5 seconds for any possible retry attempts that might be pending, and
    # then ensure the backend has still only been called once.
    sleep 5
    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=post-between-varnish-timeout")
    assert_response_code(200, response)
    assert_equal("1", response.body)
  end

  # This is to check the behavior of nginx's max_fails=0 in our gatekeeper
  # backend setup, to ensure a bunch of backend timeouts don't accidentally
  # remove all the gatekeepers from load balancing rotation.
  def test_backend_remains_in_rotation_after_timeouts
    timeout_hydra = Typhoeus::Hydra.new
    timeout_requests = Array.new(50) do
      delay = $config["nginx"]["proxy_connect_timeout"] + 5
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
    end

    assert_equal(50, info_requests.length)
    info_requests.each do |request|
      assert_response_code(200, request.response)
    end
  end
end
