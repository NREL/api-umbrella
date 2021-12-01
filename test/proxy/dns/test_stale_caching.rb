require_relative "../../test_helper"

class Test::Proxy::Dns::TestStaleCaching < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Dns
  include Minitest::Hooks

  MAX_STALE = 3

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        "dns_resolver" => {
          "nameservers" => ["[127.0.0.1]:#{$config["unbound"]["port"]}"],
          "max_stale" => MAX_STALE,
          "negative_ttl" => false,
        },
      }, "--router")
    end
  end

  def after_all
    super
    override_config_reset("--router")
  end

  def test_nxdomain_host_down_immediately_after_ttl_expires
    ttl = 4
    set_dns_records(["#{unique_test_hostname} #{ttl} A 127.0.0.1"])

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => unique_test_hostname,
        :servers => [{ :host => unique_test_hostname, :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/stale-caching-down-after-ttl-expires/", :backend_prefix => "/info/" }],
      },
    ]) do
      wait_for_response("/#{unique_test_id}/stale-caching-down-after-ttl-expires/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      set_dns_records([], ["local-zone: '#{unique_test_hostname}' always_nxdomain"])
      start_time = Time.now.utc
      wait_for_response("/#{unique_test_id}/stale-caching-down-after-ttl-expires/", {
        :code => 500,
        :body => /Unknown Host/,
      })
      duration = Time.now.utc - start_time
      min_duration = ttl - TTL_BUFFER_NEG
      max_duration = ttl + TTL_BUFFER_POS
      assert_operator(min_duration, :>, 0)
      assert_operator(duration, :>=, min_duration)
      assert_operator(duration, :<, max_duration)
    end
  end

  def test_failed_host_down_after_ttl_and_stale_time_expires
    ttl = 4
    set_dns_records(["#{unique_test_hostname} #{ttl} A 127.0.0.1"])

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => unique_test_hostname,
        :servers => [{ :host => unique_test_hostname, :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/stale-caching-down-after-ttl-expires/", :backend_prefix => "/info/" }],
      },
    ]) do
      wait_for_response("/#{unique_test_id}/stale-caching-down-after-ttl-expires/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      set_dns_records([], ["local-zone: '#{unique_test_hostname}' always_refuse"])
      start_time = Time.now.utc
      wait_for_response("/#{unique_test_id}/stale-caching-down-after-ttl-expires/", {
        :code => 500,
        :body => /Unknown Host/,
      })
      duration = Time.now.utc - start_time
      min_duration = ttl + MAX_STALE - TTL_BUFFER_NEG
      # Double the TTL buffer factor on this test, to account for further
      # fuzziness with the timings of the stale record too.
      max_duration = ttl + MAX_STALE + TTL_BUFFER_POS * 2
      assert_operator(min_duration, :>, 0)
      assert_operator(duration, :>=, min_duration)
      assert_operator(duration, :<, max_duration)
    end
  end
end
