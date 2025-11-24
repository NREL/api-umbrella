require_relative "../../test_helper"

class Test::Proxy::KeepAlive::TestServerSide < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    reset_api_backend_idle_connections
    @keepalive_idle_timeout = 2
    @nginx_workers = 2
    @nginx_upstream_keepalive_connections_per_worker = 15
    @router_keepalive_connections = 25
    once_per_class_setup do
      override_config_set({
        :nginx => {
          :workers => @nginx_workers,
          :upstream_keepalive_connections_per_worker => @nginx_upstream_keepalive_connections_per_worker,
          :upstream_keepalive_idle_timeout => @keepalive_idle_timeout,
        },
        :router => {
          :api_backends => {
            :keepalive_idle_timeout => @keepalive_idle_timeout,
            :keepalive_connections => @router_keepalive_connections,
          },
        },
      })

      prepend_api_backends([
        {
          :name => unique_test_class_id,
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/keepalive-default/", :backend_prefix => "/" }],
        },
      ])
    end
    @api_backend = ApiBackend.find_by!(name: unique_test_class_id)
  end

  def after_all
    super
    override_config_reset
  end

  def test_keeps_idle_connections_open
    # TODO: Revisit when TrafficServer 9.2+ is released, since I think that
    # might fix things: https://github.com/apache/trafficserver/pull/8083 In
    # the meantime, the current behavior means idle connections perhaps stay
    # around too long, but I think this should be okay for now.
    # skip("Keepalive idle handling doesn't work as expected in Traffic Server 9.1, but the behavior should still be acceptable. Revisit in Traffic Server 9.2+.")

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
    # to ensure it's just few (for the current connection). Keepalive
    # connections are lazily established, so this just verifies the current
    # behavior of the connections only being kept once they're actually used.
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options)
    assert_response_code(200, response)
    stats = connection_stats
    ap stats
    assert_includes(1..4, stats.fetch(:nginx_router_to_trafficserver_active_connections_per_trafficserver))
    assert_includes(1..4, stats.fetch(:trafficserver_to_envoy_active_connections_per_trafficserver))
    assert_includes(1..4, stats.fetch(:trafficserver_to_envoy_active_connections_per_envoy))
    assert_includes(1..4, stats.fetch(:envoy_to_api_backend_active_connections_per_envoy))
    assert_includes(1..4, stats.fetch(:envoy_to_api_backend_active_connections_per_api_backend))
    assert_includes(1..4, stats.fetch(:envoy_to_api_backend_idle_connections_per_api_backend))

    # Open a bunch of concurrent connections first, and then inspect the number
    # of number of connections still active afterwards.
    max_concurrency = 200
    hydra = Typhoeus::Hydra.new(max_concurrency: max_concurrency)
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
    stats = connection_stats
    ap stats
    assert_in_delta(@nginx_upstream_keepalive_connections_per_worker * @nginx_workers, stats.fetch(:nginx_router_to_trafficserver_active_connections_per_trafficserver), 5)
    assert_operator(stats.fetch(:nginx_router_to_trafficserver_active_connections_per_trafficserver), :<=, max_concurrency)
    assert_operator(stats.fetch(:trafficserver_to_envoy_active_connections_per_trafficserver), :>, idle_connections + 2)
    assert_operator(stats.fetch(:trafficserver_to_envoy_active_connections_per_trafficserver), :<=, max_concurrency)
    assert_operator(stats.fetch(:trafficserver_to_envoy_active_connections_per_envoy), :>, idle_connections + 2)
    assert_operator(stats.fetch(:trafficserver_to_envoy_active_connections_per_envoy), :<=, max_concurrency)
    assert_operator(stats.fetch(:envoy_to_api_backend_active_connections_per_envoy), :>, idle_connections + 2)
    assert_operator(stats.fetch(:envoy_to_api_backend_active_connections_per_envoy), :<=, max_concurrency)
    assert_operator(stats.fetch(:envoy_to_api_backend_active_connections_per_api_backend), :>, idle_connections + 2)
    assert_operator(stats.fetch(:envoy_to_api_backend_active_connections_per_api_backend), :<=, max_concurrency)
    assert_operator(stats.fetch(:envoy_to_api_backend_idle_connections_per_api_backend), :>, idle_connections + 2)
    assert_operator(stats.fetch(:envoy_to_api_backend_idle_connections_per_api_backend), :<=, max_concurrency)

    300.times do
      request = Typhoeus::Request.new("http://127.0.0.1:9080#{path}", http_options)
      request.on_complete do |resp|
        assert_response_code(200, resp)
      end
      hydra.queue(request)
    end
    hydra.run

    stats = connection_stats
    ap stats

    # Wait for the keepalive timeout to expire, after which the number of idle
    # connections should be lowered to just the persistent ones that are kept
    # around.
    begin
      data = nil
      # This should generally happen within "keepalive_idle_timeout" seconds,
      # but add a considerable buffer to this, since we see some some sporadic
      # issues where this sometimes takes longer in the test suite (but the
      # exact timing of this behavior isn't really that important).
      Timeout.timeout(@keepalive_idle_timeout + 300) do
        loop do
          stats = connection_stats
          ap stats

          # response = Typhoeus.get("http://127.0.0.1:13001/stats?filter=downstream_cx", http_options)
          # if(response.code == 200)
          #   puts response.body
          # end

          # response = Typhoeus.get("http://127.0.0.1:13009/_stats/csv", http_options)
          # if(response.code == 200)
          #   puts response.body
          # end


          # response = Typhoeus.get("http://127.0.0.1:9444/connection-stats/", http_options)
          # if(response.code == 200)
          #   data = MultiJson.load(response.body)
          #   ap data
          #   if(data["connections_waiting"] <= idle_connections + 2)
          #     break
          #   end
          # end

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

  def connection_stats
    stats = {}

    response = Typhoeus.get("http://127.0.0.1:9444/connection-stats/", http_options)
    assert_response_code(200, response)
    stats[:api_backend] = MultiJson.load(response.body)

    response = Typhoeus.get("http://127.0.0.1:13001/stats", http_options.deep_merge({
      params: {
        format: "json",
        filter: "(downstream_cx|upstream_cx)",
      },
    }))
    assert_response_code(200, response)
    stats[:envoy] = MultiJson.load(response.body).fetch("stats").each_with_object({}) { |stat, data| data[stat["name"]] = stat["value"] if stat["name"] }

    response = Typhoeus.get("http://127.0.0.1:13009/_stats", http_options)
    assert_response_code(200, response)
    stats[:trafficserver] = MultiJson.load(response.body).fetch("global").each_with_object({}) { |(key, value), data| data[key] = Integer(value, exception: false) || Float(value, exception: false) || value }

    stats[:nginx_router_to_trafficserver_active_connections_per_trafficserver] = stats.fetch(:trafficserver).fetch("proxy.process.http.current_client_connections")
    stats[:trafficserver_to_envoy_active_connections_per_trafficserver] = stats.fetch(:trafficserver).fetch("proxy.process.http.current_server_connections")
    stats[:trafficserver_to_envoy_active_connections_per_envoy] = stats.fetch(:envoy).fetch("http.router.downstream_cx_active")
    stats[:envoy_to_api_backend_active_connections_per_envoy] = stats.fetch(:envoy).fetch("cluster.api-backend-cluster-#{@api_backend.id}.upstream_cx_active")
    stats[:envoy_to_api_backend_active_connections_per_api_backend] = stats.fetch(:api_backend).fetch("connections_active")
    stats[:envoy_to_api_backend_idle_connections_per_api_backend] = stats.fetch(:api_backend).fetch("connections_waiting")
    # assert_operator(.to_i, :>, idle_connections + 2)
    # assert_operator(stats.fetch(:trafficserver).fetch("proxy.process.http.current_server_connections").to_i, :>, idle_connections + 2)
    # assert_operator(stats.fetch(:trafficserver).fetch("proxy.process.http.pooled_server_connections").to_i, :>, idle_connections + 2)
    # assert_operator(stats.fetch(:envoy).fetch("http.router.downstream_cx_active"), :>, idle_connections + 2)
    # assert_equal(0, stats.fetch(:envoy).fetch("http.router.downstream_cx_destroy_remote"))
    # assert_operator(stats.fetch(:api_backend).fetch("connections_waiting"), :>, idle_connections + 2)

    stats
  end
end
