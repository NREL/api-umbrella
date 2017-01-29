require_relative "../../test_helper"

class Test::Proxy::Dns::TestCustomServer < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Dns
  include Minitest::Hooks

  def setup
    super
    @local_interface_ips = [
      "127.0.0.1",
      "127.0.0.2",
      "127.0.0.3",
      "127.0.0.4",
      "127.0.0.5",
    ]

    setup_server
    once_per_class_setup do
      override_config_set({
        "dns_resolver" => {
          "nameservers" => ["[127.0.0.1]:#{$config["unbound"]["port"]}"],
          "max_stale" => 0,
          "negative_ttl" => false,
        },
      }, "--router")
    end
  end

  def after_all
    super
    override_config_reset("--router")
  end

  def test_begins_resolving
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "invalid-hostname-begins-resolving.ooga",
        :servers => [{ :host => "invalid-hostname-begins-resolving.ooga", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/invalid-hostname-begins-resolving/", :backend_prefix => "/info/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/invalid-hostname-begins-resolving/", http_options)
      assert_response_code(502, response)

      set_dns_records(["invalid-hostname-begins-resolving.ooga 60 A 127.0.0.1"])

      wait_for_response("/#{unique_test_id}/invalid-hostname-begins-resolving/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })
    end
  end

  def test_refreshes_after_ttl
    ttl = 4
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "refresh-after-ttl-expires.ooga",
        :servers => [{ :host => "refresh-after-ttl-expires.ooga", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/refresh-after-ttl-expires/", :backend_prefix => "/info/" }],
      },
    ]) do
      set_dns_records(["refresh-after-ttl-expires.ooga #{ttl} A 127.0.0.1"])
      wait_for_response("/#{unique_test_id}/refresh-after-ttl-expires/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      set_dns_records(["refresh-after-ttl-expires.ooga #{ttl} A 127.0.0.2"])
      start_time = Time.now.utc
      wait_for_response("/#{unique_test_id}/refresh-after-ttl-expires/", {
        :code => 200,
        :local_interface_ip => "127.0.0.2",
      })
      duration = Time.now.utc - start_time
      min_duration = ttl - TTL_BUFFER_NEG
      max_duration = ttl + TTL_BUFFER_POS
      assert_operator(min_duration, :>, 0)
      assert_operator(duration, :>=, min_duration)
      assert_operator(duration, :<, max_duration)
    end
  end

  def test_failed_host_down_after_ttl_expires
    ttl = 4
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "down-after-ttl-expires.ooga",
        :servers => [{ :host => "down-after-ttl-expires.ooga", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/down-after-ttl-expires/", :backend_prefix => "/info/" }],
      },
    ]) do
      set_dns_records(["down-after-ttl-expires.ooga #{ttl} A 127.0.0.1"])
      wait_for_response("/#{unique_test_id}/down-after-ttl-expires/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      set_dns_records([])
      start_time = Time.now.utc
      wait_for_response("/#{unique_test_id}/down-after-ttl-expires/", {
        :code => 502,
      })
      duration = Time.now.utc - start_time
      min_duration = ttl - TTL_BUFFER_NEG
      max_duration = ttl + TTL_BUFFER_POS
      assert_operator(min_duration, :>, 0)
      assert_operator(duration, :>=, min_duration)
      assert_operator(duration, :<, max_duration)
    end
  end

  def test_ongoing_dns_changes
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "ongoing-changes.ooga",
        :servers => [{ :host => "ongoing-changes.ooga", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/ongoing-changes/", :backend_prefix => "/info/" }],
      },
    ]) do
      set_dns_records(["ongoing-changes.ooga 1 A 127.0.0.1"])
      wait_for_response("/#{unique_test_id}/ongoing-changes/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      set_dns_records(["ongoing-changes.ooga 1 A 127.0.0.2"])
      wait_for_response("/#{unique_test_id}/ongoing-changes/", {
        :code => 200,
        :local_interface_ip => "127.0.0.2",
      })

      set_dns_records(["ongoing-changes.ooga 1 A 127.0.0.3"])
      wait_for_response("/#{unique_test_id}/ongoing-changes/", {
        :code => 200,
        :local_interface_ip => "127.0.0.3",
      })

      set_dns_records(["ongoing-changes.ooga 1 A 127.0.0.4"])
      wait_for_response("/#{unique_test_id}/ongoing-changes/", {
        :code => 200,
        :local_interface_ip => "127.0.0.4",
      })
    end
  end

  def test_load_balances_across_multiple_ips
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "multiple-ips.ooga",
        :servers => [{ :host => "multiple-ips.ooga", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/multiple-ips/", :backend_prefix => "/info/" }],
      },
    ]) do
      records = @local_interface_ips.map { |ip| "multiple-ips.ooga 60 A #{ip}" }
      set_dns_records(records)
      wait_for_response("/#{unique_test_id}/multiple-ips/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      hydra = Typhoeus::Hydra.new(:max_concurrency => 10)
      requests = Array.new(250) do
        request = Typhoeus::Request.new("http://127.0.0.1:9080/#{unique_test_id}/multiple-ips/", http_options)
        hydra.queue(request)
        request
      end
      hydra.run

      seen_ips = Set.new
      requests.each do |request|
        assert_response_code(200, request.response)
        data = MultiJson.load(request.response.body)
        seen_ips << data["local_interface_ip"]
      end

      # Make sure all the different loopback IPs defined for this hostname were
      # actually used.
      assert_equal(@local_interface_ips.sort, seen_ips.to_a.sort)
    end
  end

  def test_ip_changes_without_dropped_connections
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "no-drops-during-changes.ooga",
        :servers => [{ :host => "no-drops-during-changes.ooga", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/no-drops-during-changes/", :backend_prefix => "/info/" }],
      },
    ]) do
      set_dns_records(["no-drops-during-changes.ooga 1 A 127.0.0.1"])
      wait_for_response("/#{unique_test_id}/no-drops-during-changes/", {
        :code => 200,
        :local_interface_ip => "127.0.0.1",
      })

      # While the requests are being made in parallel, change the DNS for this
      # domain.
      change_thread = Thread.new do
        loop do
          # Change the DNS again in less than a second.
          sleep rand(0.0..1.0)

          # Use a random local IP to trigger change.
          random_ip = @local_interface_ips.sample

          # Make sure things work with both a short TTL and no TTL.
          random_ttl = [0, 1].sample

          set_dns_records(["no-drops-during-changes.ooga #{random_ttl} A #{random_ip}"])
        end
      end

      # For a period of time we'll make lots of parallel requests while
      # simultaneously triggering DNS changes.
      #
      # We default to 20 seconds, but allow an environment variable override
      # for much longer tests for debugging.
      test_duration = (ENV["CONNECTION_DROPS_DURATION"] || 20).to_i
      start_time = Time.now.utc
      hydra = Typhoeus::Hydra.new(:max_concurrency => 25)
      requests = []
      100.times do
        # Recursive callback to keep making parallel requests until the test
        # duration is hit.
        on_complete = proc do
          if(Time.now.utc - start_time < test_duration)
            request = Typhoeus::Request.new("http://127.0.0.1:9080/#{unique_test_id}/no-drops-during-changes/", http_options)
            request.on_complete(&on_complete)
            requests << request
            hydra.queue(request)
          end
        end

        # Queue initial requests
        on_complete.call
      end
      hydra.run

      change_thread.exit

      # Ensure the requests were called recursively and throughout the test
      # duration.
      assert_operator(requests.length, :>, 300)

      seen_ips = Set.new
      requests.each do |request|
        assert_response_code(200, request.response)
        data = MultiJson.load(request.response.body)
        seen_ips << data["local_interface_ip"]
      end

      # Ensure we saw a mix of the different loopback addresses in effect
      # (ideally, we'd ensure that we saw all the addresses, but given the
      # randomness of this test, we'll just ensure we saw at least a couple).
      assert_operator(seen_ips.length, :>=, 2)
    end
  end

  def test_resolves_newly_published_apis
    set_dns_records(["newly-published-backend.ooga 1 A 127.0.0.2"])

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "newly-published-backend.ooga",
        :servers => [{ :host => "newly-published-backend.ooga", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/newly-published-backend/", :backend_prefix => "/info/" }],
      },
    ]) do
      wait_for_response("/#{unique_test_id}/newly-published-backend/", {
        :code => 200,
        :local_interface_ip => "127.0.0.2",
      })
    end
  end
end
