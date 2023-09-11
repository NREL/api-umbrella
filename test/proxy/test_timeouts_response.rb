require_relative "../test_helper"

class Test::Proxy::TestTimeoutsResponse < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  # While these tests can be parallelized, given the timing sensitivities of
  # them, we will not parallelize them to cut down on flaky tests due to the
  # timings being skewed by other activity.
  # parallelize_me!

  BUFFER_TIME_LOWER = 0.15
  BUFFER_TIME_UPPER = 1.5

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        "nginx" => {
          "proxy_connect_timeout" => 2,
          "proxy_read_timeout" => 5,
          "proxy_send_timeout" => 10,
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_response_sent_before_timeout
    read_timeout = $config["nginx"]["proxy_read_timeout"]
    delay = read_timeout - 2
    assert_operator(delay, :>, 0)
    assert_operator(delay, :<, read_timeout)

    response = Typhoeus.get("http://127.0.0.1:9080/api/delay-sec/#{delay}", http_options)
    assert_response_code(200, response)
    assert_operator(response.total_time, :>, delay - BUFFER_TIME_LOWER)
  end

  def test_response_sent_after_timeout
    read_timeout = $config["nginx"]["proxy_read_timeout"]
    delay = read_timeout + 2
    assert_operator(delay, :>, read_timeout)

    response = Typhoeus.get("http://127.0.0.1:9080/api/delay-sec/#{delay}", http_options)
    assert_response_code(504, response)
    assert_match("Inactivity Timeout", response.body)
    assert_operator(response.total_time, :>, read_timeout - BUFFER_TIME_LOWER)
    assert_operator(response.total_time, :<=, read_timeout + BUFFER_TIME_UPPER)
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
