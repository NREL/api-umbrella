require_relative "../test_helper"

class Test::Proxy::TestHostSslCerts < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Dns
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        "hosts" => [
          {
            "hostname" => "ssl.foo",
            "ssl_cert" => File.join(API_UMBRELLA_SRC_ROOT, "test/config/ssl_test.crt"),
            "ssl_cert_key" => File.join(API_UMBRELLA_SRC_ROOT, "test/config/ssl_test.key"),
          },
        ],
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_default_self_signed_cert
    ssl_client = OpenSSL::SSL::SSLSocket.new(TCPSocket.new("127.0.0.1", 9081), OpenSSL::SSL::SSLContext.new)
    ssl_client.connect
    assert_equal("/O=API Umbrella/CN=apiumbrella.example.com", ssl_client.peer_cert.subject.to_s)
  end

  def test_default_cert_for_unknown_host
    ssl_client = OpenSSL::SSL::SSLSocket.new(TCPSocket.new("127.0.0.1", 9081), OpenSSL::SSL::SSLContext.new)
    ssl_client.hostname = "unknown.foo"
    ssl_client.connect
    assert_equal("/O=API Umbrella/CN=apiumbrella.example.com", ssl_client.peer_cert.subject.to_s)
  end

  def test_sni_for_configured_hosts
    ssl_client = OpenSSL::SSL::SSLSocket.new(TCPSocket.new("127.0.0.1", 9081), OpenSSL::SSL::SSLContext.new)
    ssl_client.hostname = "ssl.foo"
    ssl_client.connect
    assert_equal("/O=API Umbrella/CN=ssltest.example.com", ssl_client.peer_cert.subject.to_s)
  end
end
