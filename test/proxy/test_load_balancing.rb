require_relative "../test_helper"

class Test::Proxy::TestLoadBalancing < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_single_backend_server
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      stats = make_requests(100)
      assert_equal(100, stats[:hosts]["127.0.0.1"])
      assert_equal(100, stats[:local_interface_ips]["127.0.0.1"])
    end
  end

  def test_balances_across_multiple_backend_servers
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [
          { :host => "127.0.0.1", :port => 9444 },
          { :host => "127.0.0.2", :port => 9444 },
          { :host => "127.0.0.3", :port => 9444 },
        ],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      stats = make_requests(100)
      assert_equal(100, stats[:hosts]["127.0.0.1"])
      assert_operator(stats[:local_interface_ips]["127.0.0.1"], :>=, 15)
      assert_operator(stats[:local_interface_ips]["127.0.0.2"], :>=, 15)
      assert_operator(stats[:local_interface_ips]["127.0.0.3"], :>=, 15)
    end
  end

  private

  def make_requests(count)
    stats = {
      :hosts => {},
      :local_interface_ips => {},
    }

    hydra = Typhoeus::Hydra.new
    requests = Array.new(count) do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options)
      hydra.queue(request)
      request
    end
    hydra.run

    requests.each do |request|
      assert_response_code(200, request.response)
      data = MultiJson.load(request.response.body)

      ip = data.fetch("local_interface_ip")
      assert(ip)
      stats[:local_interface_ips][ip] ||= 0
      stats[:local_interface_ips][ip] += 1

      host = data.fetch("headers").fetch("host")
      assert(host)
      stats[:hosts][host] ||= 0
      stats[:hosts][host] += 1
    end

    stats
  end
end
