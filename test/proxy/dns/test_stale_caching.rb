require_relative "../../test_helper"

# When we used Trafficserver for DNS resolving, we supported a
# "dns_resolver.max_stale" option that set a cap on how long stale entries
# could be kept around. However, Envoy doesn't currently support this, so we
# have removed that option and will instead test to ensure stale entries are
# kept around indefinitely.
#
# It's possible Envoy could add a maximum stale lifespan in the future, in
# which case we could revisit adding that option back in (and adjusting these
# tests):
# https://github.com/envoyproxy/envoy/issues/16314
# https://github.com/envoyproxy/envoy/issues/15457
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
          "negative_ttl" => false,
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_nxdomain_host_expires_stale
    ttl = 4
    set_dns_records(["#{unique_test_hostname} #{ttl} A 127.0.0.1"])

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => unique_test_hostname,
        :servers => [{ :host => unique_test_hostname, :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/" }],
      },
    ]) do
      wait_for_response("/#{unique_test_id}/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })
      start_time = Time.now.utc

      set_dns_records([], ["local-zone: '#{unique_test_hostname}' always_nxdomain"])
      wait_for_response("/#{unique_test_id}/", {
        :code => 503,
      })
      duration = Time.now.utc - start_time
      min_duration = ttl - TTL_BUFFER_NEG
      max_duration = ttl + TTL_BUFFER_POS
      assert_operator(min_duration, :>, 0)
      assert_operator(duration, :>=, min_duration)
      assert_operator(duration, :<, max_duration)
    end
  end

  def test_nodata_host_expires_stale
    ttl = 4
    set_dns_records(["#{unique_test_hostname} #{ttl} A 127.0.0.1"])

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => unique_test_hostname,
        :servers => [{ :host => unique_test_hostname, :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/" }],
      },
    ]) do
      wait_for_response("/#{unique_test_id}/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })
      start_time = Time.now.utc

      set_dns_records([], ["local-zone: '#{unique_test_hostname}' always_nodata"])
      wait_for_response("/#{unique_test_id}/", {
        :code => 503,
      })
      duration = Time.now.utc - start_time
      min_duration = ttl - TTL_BUFFER_NEG
      max_duration = ttl + TTL_BUFFER_POS
      assert_operator(min_duration, :>, 0)
      assert_operator(duration, :>=, min_duration)
      assert_operator(duration, :<, max_duration)
    end
  end

  def test_deny_host_keeps_stale_indefinitely
    ttl = 4
    set_dns_records(["#{unique_test_hostname} #{ttl} A 127.0.0.1"])

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => unique_test_hostname,
        :servers => [{ :host => unique_test_hostname, :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/" }],
      },
    ]) do
      wait_for_response("/#{unique_test_id}/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      set_dns_records([], ["local-zone: '#{unique_test_hostname}' always_deny"])

      request_count = 0
      run_until = Time.now + (ttl * 2) + TTL_BUFFER_POS
      while Time.now <= run_until
        response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/", http_options)
        request_count += 1
        assert_response_code(200, response)
        sleep 0.1
      end

      assert_operator(request_count, :>, 10)
    end
  end

  def test_failed_host_keeps_stale_indefinitely
    ttl = 4
    set_dns_records(["#{unique_test_hostname} #{ttl} A 127.0.0.1"])

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => unique_test_hostname,
        :servers => [{ :host => unique_test_hostname, :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/" }],
      },
    ]) do
      wait_for_response("/#{unique_test_id}/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      set_dns_records([], ["local-zone: '#{unique_test_hostname}' always_refuse"])

      request_count = 0
      run_until = Time.now + (ttl * 2) + TTL_BUFFER_POS
      while Time.now <= run_until
        response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/", http_options)
        request_count += 1
        assert_response_code(200, response)
        sleep 0.1
      end

      assert_operator(request_count, :>, 10)
    end
  end
end
