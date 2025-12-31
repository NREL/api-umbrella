require_relative "../../test_helper"

class Test::Proxy::Dns::TestNegativeCaching < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Dns
  include Minitest::Hooks

  NEGATIVE_TTL = 6

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        "dns_resolver" => {
          "nameservers" => ["[127.0.0.1]:#{$config["unbound"]["port"]}"],
          "negative_ttl" => NEGATIVE_TTL,
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_caches_failed_lookups_before_retrying
    assert_negative_ttl(NEGATIVE_TTL)
  end

  def test_negative_ttl_can_be_configured
    negative_ttl = 2

    # Ensure this negative TTL is different enough than the default that we can
    # distinguish the results in tests.
    assert_operator(negative_ttl + TTL_BUFFER_POS, :<, NEGATIVE_TTL - TTL_BUFFER_NEG)

    override_config({
      "dns_resolver" => {
        "nameservers" => ["[127.0.0.1]:#{$config["unbound"]["port"]}"],
        "negative_ttl" => negative_ttl,
      },
    }) do
      assert_negative_ttl(negative_ttl)
    end
  end

  private

  def assert_negative_ttl(negative_ttl)
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => unique_test_hostname,
        :servers => [{ :host => unique_test_hostname, :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/" }],
      },
    ]) do
      # Make an initial request, which we expect to not succeed, since the
      # hostname is bad.
      wait_for_response("/#{unique_test_id}/", {
        :code => 503,
        :body => /no healthy upstream/,
      })

      # The negative TTL caching begins after Envoy sees the first
      # request and tries to resolve it. So start our timer after the first
      # request.
      start_time = Time.now.utc

      # Add the DNS record for the previously invalid domain.
      set_dns_records(["#{unique_test_hostname} 60 A 127.0.0.1"])

      # Ensure that negative caching is in place and the hostname is still not
      # resolving (despite the DNS being installed now).
      wait_for_response("/#{unique_test_id}/", {
        :code => 503,
        :body => /no healthy upstream/,
      })

      # Wait for the successful response to resolve once the negative TTL has
      # expired.
      wait_for_response("/#{unique_test_id}/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      # Sanity check the results to ensure the results fit within the expected
      # negative TTL values.
      duration = Time.now.utc - start_time
      min_duration = negative_ttl - TTL_BUFFER_NEG
      max_duration = negative_ttl + TTL_BUFFER_POS
      assert_operator(min_duration, :>, 0)
      assert_operator(duration, :>=, min_duration)
      assert_operator(duration, :<, max_duration)
    end
  end
end
