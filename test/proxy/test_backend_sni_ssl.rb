require_relative "../test_helper"

class Test::Proxy::TestBackendSniSsl < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Dns
  include Minitest::Hooks

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

  def test_backends_requiring_sni_support
    set_dns_records([
      "sni1.sni-tests.test 60 A 127.0.0.1",
      "sni2.sni-tests.test 60 A 127.0.0.1",
    ])

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "sni1.sni-tests.test",
        :backend_protocol => "https",
        :servers => [{ :host => "sni1.sni-tests.test", :port => 9448 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/sni1/", :backend_prefix => "/" }],
      },
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "sni2.sni-tests.test",
        :backend_protocol => "https",
        :servers => [{ :host => "sni2.sni-tests.test", :port => 9448 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/sni2/", :backend_prefix => "/" }],
      },
    ]) do
      # Verify that a non-SNI connection directly to the backend fails
      # completely, rather than returning some default certificate.
      ssl_client = OpenSSL::SSL::SSLSocket.new(TCPSocket.new("127.0.0.1", 9448), OpenSSL::SSL::SSLContext.new)
      assert_raises OpenSSL::SSL::SSLError do
        ssl_client.connect
      end

      # Verify that SNI connections directly to the backend return a
      # certificate.
      ssl_client = OpenSSL::SSL::SSLSocket.new(TCPSocket.new("127.0.0.1", 9448), OpenSSL::SSL::SSLContext.new)
      ssl_client.hostname = "sni1.sni-tests.test"
      ssl_client.connect
      assert_equal("/O=API Umbrella/CN=ssltest.example.com", ssl_client.peer_cert.subject.to_s)
      ssl_client = OpenSSL::SSL::SSLSocket.new(TCPSocket.new("127.0.0.1", 9448), OpenSSL::SSL::SSLContext.new)
      ssl_client.hostname = "sni2.sni-tests.test"
      ssl_client.connect
      assert_equal("/O=API Umbrella/CN=ssltest.example.com", ssl_client.peer_cert.subject.to_s)

      # Ensure that proxied requests to the SNI backends work successfully.
      # These would fail if our proxy doesn't use SNI for communication with
      # the backend.
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/sni1/", http_options)
      assert_response_code(200, response)
      assert_equal("SNI1", response.body)
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/sni2/", http_options)
      assert_response_code(200, response)
      assert_equal("SNI2", response.body)
    end
  end
end
