require_relative "../../test_helper"

class TestProxyDnsNegativeCaching < Minitest::Test
  include ApiUmbrellaTests::Setup
  include ApiUmbrellaTests::Dns
  include Minitest::Hooks

  NEGATIVE_TTL = 6

  def setup
    setup_server
    once_per_class_setup do
      override_config_set({
        "dns_resolver" => {
          "nameservers" => ["[127.0.0.1]:#{$config["unbound"]["port"]}"],
          "max_stale" => 0,
          "negative_ttl" => NEGATIVE_TTL,
        },
      }, "--router")
    end
  end

  def after_all
    super
    override_config_reset("--router")
  end

  def test_failed_host_down_after_ttl_expires
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "negative-caching-invalid-hostname-begins-resolving.ooga",
        :servers => [{ :host => "negative-caching-invalid-hostname-begins-resolving.ooga", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/negative-caching-invalid-hostname-begins-resolving/", :backend_prefix => "/info/" }],
      },
    ]) do
      # The negative TTL caching really begins as soon as the initial
      # configuration is put into place by runServer (since that's when the
      # hostname is first seen and the unresolvable status is cached). So start
      # our timer here.
      start_time = Time.now.utc

      wait_for_response("/#{unique_test_id}/negative-caching-invalid-hostname-begins-resolving/", {
        :code => 502,
      })

      set_dns_records(["negative-caching-invalid-hostname-begins-resolving.ooga 60 A 127.0.0.1"])
      wait_for_response("/#{unique_test_id}/negative-caching-invalid-hostname-begins-resolving/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })
      duration = Time.now.utc - start_time
      assert_operator(duration, :>=, (NEGATIVE_TTL - TTL_BUFFER))
      assert_operator(duration, :<, (NEGATIVE_TTL + TTL_BUFFER))
    end
  end
end
