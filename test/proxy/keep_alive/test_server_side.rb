require_relative "../../test_helper"

class Test::Proxy::KeepAlive::TestServerSide < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    reset_nginx_connections
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/keepalive-default/", :backend_prefix => "/" }],
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/keepalive-2/", :backend_prefix => "/" }],
          :keepalive_connections => 2,
        },
      ])
    end
  end

  def test_keeps_idle_connections_open
    assert_idle_connections("/#{unique_test_class_id}/keepalive-default/connection-stats/", $config["router"]["api_backends"]["keepalive_connections"])
  end

  def test_configurable_number_of_idle_connections
    assert_idle_connections("/#{unique_test_class_id}/keepalive-2/connection-stats/", 2)
  end

  def test_concurrent_backend_connections_can_exceed_keepalive_count
    max_connections_active = 0
    max_connections_writing = 0
    hydra = Typhoeus::Hydra.new
    500.times do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/#{unique_test_class_id}/keepalive-default/connection-stats/", http_options)
      request.on_complete do |response|
        assert_equal(200, response.code, response.body)
        data = MultiJson.load(response.body)

        if(data["connections_active"] > max_connections_active)
          max_connections_active = data["connections_active"]
        end

        if(data["connections_writing"] > max_connections_writing)
          max_connections_writing = data["connections_writing"]
        end
      end
      hydra.queue(request)
    end
    hydra.run

    # Ensure that the number of concurrent requests at some point exceeded
    # the default number of keepalive connections per backend.
    assert_operator(max_connections_active, :>=, $config["router"]["api_backends"]["keepalive_connections"] * $config["nginx"]["workers"])
    assert_operator(max_connections_writing, :>=, $config["router"]["api_backends"]["keepalive_connections"] * $config["nginx"]["workers"])
  end

  private

  def reset_nginx_connections
    # Reload the test nginx server to close any persistent keep-alive
    # connections API Umbrella is holding against it.
    output, status = Open3.capture2e("perpctl -b #{File.join($config["root_dir"], "etc/perp")} hup test-env-nginx")
    assert_equal(0, status, output)

    # After reloading nginx, ensure we wait until there are no more idle
    # connections, so our checks for counts are isolated to each test.
    begin
      data = nil
      Timeout.timeout(5) do
        loop do
          response = Typhoeus.get("http://127.0.0.1:9444/connection-stats/", http_options)
          if(response.code == 200)
            data = MultiJson.load(response.body)
            if(data["connections_waiting"] == 0)
              break
            end
          end

          sleep 0.1
        end
      end
    rescue Timeout::Error
      raise Timeout::Error, "nginx still has idle connections waiting. This is not expected after the reload. Last connection stats: #{data.inspect}"
    end
  end

  def assert_idle_connections(path, idle_per_worker)
    # Open a bunch of concurrent connections first, and then inspect the number
    # of number of connections still active afterwards.
    hydra = Typhoeus::Hydra.new
    500.times do
      request = Typhoeus::Request.new("http://127.0.0.1:9080#{path}", http_options)
      request.on_complete do |response|
        assert_equal(200, response.code, response.body)
      end
      hydra.queue(request)
    end
    hydra.run

    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options)
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)

    # The number of keepalive connections being kept open should correspond to
    # the number of nginx workers we used. For example, a setting of "keepalive
    # 10" and 4 nginx workers should result in 40 keepalive connections being
    # kept open.
    #
    # However, we will loosen our count checks, since not all the nginx workers
    # may have fully been saturated when establishing connections to the API
    # backend. Since we're mainly interested in ensuring some unused
    # connections are being kept open, we'll loosen our count checks.
    #
    # Note: Our `exercise_all_workers` test helper won't help make our count
    # checks less ambiguous for a couple reasons, so don't be tempted to use
    # that here. The test helper only exercises the nginx workers initially
    # receiving the requests, but here we're dealing with nginx workers that
    # route to the API backend (after TrafficServer). Plus, that test helper
    # just ensures all the workers are hit once, but does not guarantee they're
    # fully saturated with multiple parallel requests (as needed in this case
    # to open up the number of expected keepalive connections).

    # The only request being made should be the one to fetch connection stats.
    assert_equal(1, data["connections_writing"])

    # Check the "active" count from nginx, which includes idle connections and
    # any in-use connections (with our request to fetch connection stats being
    # the only in-use one).
    assert_operator(data["connections_active"], :>=, idle_per_worker)
    assert_operator(data["connections_active"], :<=, idle_per_worker * $config["nginx"]["workers"])

    # Check the "waiting" count from nginx, which is just the idle connections.
    # This will be 1 less than the expected keepalive count, since one of those
    # connections will probably be used for the connection stats request (but
    # not necessarily, so this is why we only subtract 1 from the minimum
    # count).
    assert_operator(data["connections_waiting"], :>=, idle_per_worker - 1)
    assert_operator(data["connections_waiting"], :<=, idle_per_worker * $config["nginx"]["workers"])
  end
end
