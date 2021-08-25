require_relative "../../test_helper"

class Test::Proxy::KeepAlive::TestServerSide < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    reset_api_backend_idle_connections
    @keepalive_idle_timeout = 2
    once_per_class_setup do
      override_config_set({
        :router => {
          :api_backends => {
            :keepalive_idle_timeout => @keepalive_idle_timeout,
          },
        },
      }, ["--router"])

      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/keepalive-default/", :backend_prefix => "/" }],
        },
      ])
    end
  end

  def after_all
    super
    override_config_reset(["--router"])
  end

  def test_keeps_idle_connections_open
    # TODO: Revisit when TrafficServer 9.2+ is released, since I think that
    # might fix things: https://github.com/apache/trafficserver/pull/8083 In
    # the meantime, the current behavior means idle connections perhaps stay
    # around too long, but I think this should be okay for now.
    skip("Keepalive idle handling doesn't work as expected in Traffic Server 9.1, but the behavior should still be acceptable. Revisit in Traffic Server 9.2+.")

    assert_idle_connections("/#{unique_test_class_id}/keepalive-default/connection-stats/", $config["router"]["api_backends"]["keepalive_connections"])
  end

  def test_concurrent_backend_connections_can_exceed_keepalive_count
    max_connections_active = 0
    max_connections_writing = 0
    hydra = Typhoeus::Hydra.new(:max_concurrency => 200)
    500.times do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/#{unique_test_class_id}/keepalive-default/connection-stats/", http_options)
      request.on_complete do |response|
        assert_response_code(200, response)
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
    assert_operator(max_connections_active, :>, $config["router"]["api_backends"]["keepalive_connections"] + 2)
    assert_operator(max_connections_writing, :>, $config["router"]["api_backends"]["keepalive_connections"] + 2)
  end

  private

  def reset_api_backend_idle_connections
    # Restart the test nginx server to close any persistent keep-alive
    # connections API Umbrella is holding against it.
    api_umbrella_process.perp_restart("test-env-nginx")

    # After restarting nginx, ensure we wait until there are no more idle
    # connections, so our checks for counts are isolated to each test.
    begin
      data = nil
      Timeout.timeout(10) do
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
      flunk("nginx still has idle connections waiting. This is not expected after the reload. Last connection stats: #{data.inspect}")
    end
  end

  def assert_idle_connections(path, idle_connections)
    # After just making one connection, sanity check the keepalive connections
    # to ensure it's just 1-2 (for the current connection). Keepalive
    # connections are lazily established, so this just verifies the current
    # behavior of the connections only being kept once they're actually used.
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_operator(data["connections_waiting"], :<=, 2)

    # Open a bunch of concurrent connections first, and then inspect the number
    # of number of connections still active afterwards.
    hydra = Typhoeus::Hydra.new(:max_concurrency => 200)
    500.times do
      request = Typhoeus::Request.new("http://127.0.0.1:9080#{path}", http_options)
      request.on_complete do |resp|
        assert_response_code(200, resp)
      end
      hydra.queue(request)
    end
    hydra.run

    # Immediately after opening all the connections, the server should have a
    # bunch of idle connections open, since Traffic Server keeps these
    # connections around until the keepalive_idle_timeout is reached (which
    # we've lowered for testing purposes).
    response = Typhoeus.get("http://127.0.0.1:9444/connection-stats/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_operator(data["connections_waiting"], :>, idle_connections + 2)

    # Wait for the keepalive timeout to expire, after which the number of idle
    # connections should be lowered to just the persistent ones that are kept
    # around.
    begin
      data = nil
      # This should generally happen within "keepalive_idle_timeout" seconds,
      # but add a considerable buffer to this, since we see some some sporadic
      # issues where this sometimes takes longer in the test suite (but the
      # exact timing of this behavior isn't really that important).
      Timeout.timeout(@keepalive_idle_timeout + 10) do
        loop do
          response = Typhoeus.get("http://127.0.0.1:9444/connection-stats/", http_options)
          if(response.code == 200)
            data = MultiJson.load(response.body)
            if(data["connections_waiting"] <= idle_connections + 2)
              break
            end
          end

          sleep 0.1
        end
      end
    rescue Timeout::Error
      flunk("nginx did not reduce the number of idle keepalive connections kept after the expected timeout period. Last connection stats: #{data.inspect}")
    end

    # After the keepalive timeout expires, check the stats again to ensure the
    # expected number of idle connections are being kept around.
    response = Typhoeus.get("http://127.0.0.1:9444/connection-stats/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)

    # The only request being made should be the one to fetch connection stats.
    assert_equal(1, data["connections_writing"])

    # Check the "active" count from nginx, which includes idle connections and
    # any in-use connections (with our request to fetch connection stats being
    # the only in-use one).
    assert_operator(data["connections_active"], :>=, idle_connections)
    assert_operator(data["connections_active"], :<=, idle_connections + 2)

    # Check the "waiting" count from nginx, which is just the idle connections.
    # This will be 1 less than the expected keepalive count, since one of those
    # connections will probably be used for the connection stats request (but
    # not necessarily, so this is why we only subtract 1 from the minimum
    # count).
    assert_operator(data["connections_waiting"], :>=, idle_connections - 1)
    assert_operator(data["connections_waiting"], :<=, idle_connections + 2)
  end
end
