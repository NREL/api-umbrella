require_relative "../../test_helper"

class Test::Proxy::KeepAlive::TestServerSide < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::KeepAliveTestServer

  def setup
    setup_server
    start_keep_alive_test_server
    @keep_alive_backend = {
      :frontend_host => "127.0.0.1",
      :backend_host => "127.0.0.1",
      :servers => [{ :host => "127.0.0.1", :port => 9445 }],
      :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
    }
  end

  def teardown
    stop_keep_alive_test_server
  end

  def test_keeps_idle_connections_open
    prepend_api_backends([@keep_alive_backend]) do
      assert_idle_connections("/#{unique_test_id}/", 10)
    end
  end

  def test_configurable_number_of_idle_connections
    prepend_api_backends([@keep_alive_backend.merge(:keepalive_connections => 2)]) do
      assert_idle_connections("/#{unique_test_id}/", 2)
    end
  end

  def test_concurrent_backend_connections_can_exceed_keepalive_count
    max_open_connections = 0
    max_open_requests = 0
    prepend_api_backends([@keep_alive_backend]) do
      hydra = Typhoeus::Hydra.new
      requests = Array.new(500) do
        request = Typhoeus::Request.new("http://127.0.0.1:9080/#{unique_test_id}/", http_options)
        request.on_complete do |response|
          assert_equal(200, response.code, response.body)
          data = MultiJson.load(response.body)

          if(data["open_connections"] > max_open_connections)
            max_open_connections = data["open_connections"]
          end

          if(data["open_requests"] > max_open_requests)
            max_open_requests = data["open_requests"]
          end
        end
        hydra.queue(request)
        request
      end
      hydra.run

      # Ensure that the number of concurrent requests at some point exceeded
      # the default number of keepalive connections per backend.
      assert_operator(max_open_connections, :>=, 10 * $config["nginx"]["workers"])
      assert_operator(max_open_requests, :>=, 10 * $config["nginx"]["workers"])
    end
  end

  private

  def assert_idle_connections(path, idle_per_worker)
    # Open a bunch of concurrent connections first, and then inspect the number
    # of number of connections still active afterwards.
    hydra = Typhoeus::Hydra.new
    requests = Array.new(500) do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/#{unique_test_id}/", http_options)
      request.on_complete do |response|
        assert_equal(200, response.code, response.body)
      end
      hydra.queue(request)
      request
    end
    hydra.run

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/", http_options)
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)

    assert_equal(1, data["open_requests"])

    # The number of active connections afterwards should be between `idle_per_worker` and `idle_per_worker` *
    # number of nginx worker processes. This ambiguity is because we may not
    # have exercised all the individual nginx workers when establishing
    # connections to the API backend. Since we're mainly interested in ensuring
    # some unused connections are being kept open, we'll loosen our count
    # checks.
    assert_operator(data["open_connections"], :>=, idle_per_worker)
    assert_operator(data["open_connections"], :<=, idle_per_worker * $config["nginx"]["workers"])
  end
end
