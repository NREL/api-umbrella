require_relative "../test_helper"

class Test::Proxy::TestLoadBalancingDnsHostnames < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Dns
  include ApiUmbrellaTestHelpers::LoadBalancing
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        "dns_resolver" => {
          "nameservers" => ["[127.0.0.1]:#{$config["unbound"]["port"]}"],
          "max_stale" => 0,
          "negative_ttl" => false,
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_balances_across_multiple_ipv4_and_hostname_backend_servers
    override_config({
      "dns_resolver" => {
        "nameservers" => ["[127.0.0.1]:#{$config["unbound"]["port"]}"],
        "max_stale" => 0,
        "negative_ttl" => false,
      },
    }) do
      set_dns_records(["#{unique_test_hostname} 60 A 127.0.0.2"])

      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [
            { :host => "127.0.0.1", :port => 9444 },
            { :host => unique_test_hostname, :port => 9444 },
          ],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
        },
      ]) do
        stats = make_load_balancing_requests(100)
        assert_equal(100, stats[:hosts]["127.0.0.1"])
        assert_equal([
          "127.0.0.1",
          "127.0.0.2",
        ].sort, stats[:local_interface_ips].keys.sort)
        assert_operator(stats[:local_interface_ips]["127.0.0.1"], :>=, 15)
        assert_operator(stats[:local_interface_ips]["127.0.0.2"], :>=, 15)
      end
    end
  end

  # Due to current Envoy limitations. Hopefully we can allow this type of
  # behavior in the future.
  #
  # https://github.com/envoyproxy/envoy/issues/18606
  # https://github.com/envoyproxy/envoy/pull/18945
  def test_only_uses_hostnames_and_ipv4_when_mixed_with_ipv6_addresses
    override_config({
      "dns_resolver" => {
        "nameservers" => ["[127.0.0.1]:#{$config["unbound"]["port"]}"],
        "max_stale" => 0,
        "negative_ttl" => false,
      },
    }) do
      set_dns_records(["#{unique_test_hostname} 60 A 127.0.0.2"])

      log_tail = LogTail.new("nginx/current")
      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [
            { :host => "127.0.0.1", :port => 9444 },
            { :host => unique_test_hostname, :port => 9444 },
            { :host => "::1", :port => 9444 },
          ],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
        },
      ]) do
        stats = make_load_balancing_requests(100)
        assert_equal(100, stats[:hosts]["127.0.0.1"])
        assert_equal([
          "127.0.0.1",
          "127.0.0.2",
        ].sort, stats[:local_interface_ips].keys.sort)
        assert_operator(stats[:local_interface_ips]["127.0.0.1"], :>=, 15)
        assert_operator(stats[:local_interface_ips]["127.0.0.2"], :>=, 15)

        log_output = log_tail.read
        assert_match(/\[warn\].* has a mixture of IPv6 and non-IPv6 servers. This configuration is not yet supported/, log_output)
        refute_match("conflicting server name", log_output)
      end
    end
  end
end
