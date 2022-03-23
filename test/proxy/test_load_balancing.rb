require_relative "../test_helper"

class Test::Proxy::TestLoadBalancing < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::LoadBalancing
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
      stats = make_load_balancing_requests(100)
      assert_equal(100, stats[:hosts]["127.0.0.1"])
      assert_equal([
        "127.0.0.1",
      ].sort, stats[:local_interface_ips].keys.sort)
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
      stats = make_load_balancing_requests(100)
      assert_equal(100, stats[:hosts]["127.0.0.1"])
      assert_equal([
        "127.0.0.1",
        "127.0.0.2",
        "127.0.0.3",
      ].sort, stats[:local_interface_ips].keys.sort)
      assert_operator(stats[:local_interface_ips]["127.0.0.1"], :>=, 15)
      assert_operator(stats[:local_interface_ips]["127.0.0.2"], :>=, 15)
      assert_operator(stats[:local_interface_ips]["127.0.0.3"], :>=, 15)
    end
  end

  def test_balances_across_multiple_ipv4_and_ipv6_backend_servers
    skip_unless_ipv6_support

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [
          { :host => "127.0.0.1", :port => 9444 },
          { :host => "::1", :port => 9444 },
        ],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      stats = make_load_balancing_requests(100)
      assert_equal(100, stats[:hosts]["127.0.0.1"])
      assert_equal([
        "127.0.0.1",
        "::1",
      ].sort, stats[:local_interface_ips].keys.sort)
      assert_operator(stats[:local_interface_ips]["127.0.0.1"], :>=, 15)
      assert_operator(stats[:local_interface_ips]["::1"], :>=, 15)
    end
  end
end
