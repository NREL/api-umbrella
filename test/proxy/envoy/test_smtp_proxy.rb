require_relative "../../test_helper"
require "net/smtp"

class Test::Proxy::Envoy::TestSmtpProxy < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth

  def setup
    super
    setup_server
    @ssl_context_params = {
      ca_file: File.join(API_UMBRELLA_SRC_ROOT, "test/config/ssl_test.crt"),
    }
  end

  def test_disabled_by_default
    assert_raises Errno::ECONNREFUSED do
      Socket.tcp("127.0.0.1", 13003, connect_timeout: 5)
    end
  end

  def test_direct_smtp_sanity_check
    smtp = Net::SMTP.new("127.0.0.1", $config["mailpit"]["smtp_port"], starttls: :always, ssl_context_params: @ssl_context_params, tls_hostname: "ssltest.example.com")
    smtp.open_timeout = 5
    smtp.start
    assert_equal(true, smtp.esmtp?)
    assert_kind_of(Hash, smtp.capabilities)
    assert_kind_of(Array, smtp.capabilities.fetch("AUTH"))
  end

  def test_only_connects_to_single_target
    override_config({
      "envoy" => {
        "smtp_proxy" => {
          "enabled" => true,
          "endpoint" => {
            "host" => "127.0.0.1",
            "port" => $config["mailpit"]["smtp_port"],
          },
        },
      },
    }) do
      open = Socket.tcp("127.0.0.1", 13003, connect_timeout: 5) { true }
      assert_equal(true, open)

      # Verify that without an explict TLS host, we get a certificate error.
      smtp = Net::SMTP.new("127.0.0.1", 13003, starttls: :always, ssl_context_params: @ssl_context_params)
      smtp.open_timeout = 5
      error = assert_raises OpenSSL::SSL::SSLError do
        smtp.start
      end
      assert_match("certificate verify failed (hostname mismatch)", error.message)

      # Verify normal connection to the expected underlying host.
      smtp = Net::SMTP.new("127.0.0.1", 13003, starttls: :always, ssl_context_params: @ssl_context_params, tls_hostname: "ssltest.example.com")
      smtp.open_timeout = 5
      smtp.start
      assert_equal(true, smtp.esmtp?)
      assert_kind_of(Hash, smtp.capabilities)
      assert_kind_of(Array, smtp.capabilities.fetch("AUTH"))

      # Verify that trying a different TLS host also results in a certificate
      # error.
      smtp = Net::SMTP.new("127.0.0.1", 13003, starttls: :always, ssl_context_params: @ssl_context_params, tls_hostname: "email.us-east-1.amazonaws.com")
      smtp.open_timeout = 5
      error = assert_raises OpenSSL::SSL::SSLError do
        smtp.start
      end
      assert_match("certificate verify failed (hostname mismatch)", error.message)
    end
  end

  def test_web_app_uses_proxy
    override_config({
      "envoy" => {
        "smtp_proxy" => {
          "enabled" => true,
          "endpoint" => {
            "host" => "127.0.0.1",
            "port" => $config["mailpit"]["smtp_port"],
          },
        },
      },
      "web" => {
        "mailer" => {
          "smtp_settings" => {
            "address" => "127.0.0.1",
            "port" => 13003,
          },
        },
      },
    }) do
      # TODO
    end
  end
end
