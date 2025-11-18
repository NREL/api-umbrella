require_relative "../test_helper"

class Test::Proxy::TestSecurityHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_adds_security_headers_to_static_site
    response = Typhoeus.get("https://127.0.0.1:9081/signup/", keyless_http_options)
    assert_response_code(200, response)
    assert_equal("1; mode=block", response.headers["X-XSS-Protection"])
    assert_equal("DENY", response.headers["X-Frame-Options"])
    assert_equal("nosniff", response.headers["X-Content-Type-Options"])
  end

  def test_adds_security_headers_to_web_app
    FactoryBot.create(:admin)
    response = Typhoeus.get("https://127.0.0.1:9081/admin/login", keyless_http_options)
    assert_response_code(200, response)
    assert_equal("1; mode=block", response.headers["X-XSS-Protection"])
    assert_equal("DENY", response.headers["X-Frame-Options"])
    assert_equal("nosniff", response.headers["X-Content-Type-Options"])
  end

  def test_adds_security_headers_to_admin_ui
    FactoryBot.create(:admin)
    response = Typhoeus.get("https://127.0.0.1:9081/admin/login", keyless_http_options)
    assert_response_code(200, response)
    assert_equal("1; mode=block", response.headers["X-XSS-Protection"])
    assert_equal("DENY", response.headers["X-Frame-Options"])
    assert_equal("nosniff", response.headers["X-Content-Type-Options"])
  end

  def test_adds_security_headers_to_website_backends
    prepend_website_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_protocol => "http",
        :server_host => "127.0.0.1",
        :server_port => 9443,
      },
    ])

    response = Typhoeus.get("https://127.0.0.1:9081/", keyless_http_options.deep_merge({
      :headers => {
        "Host" => unique_test_hostname,
      },
    }))
    assert_response_code(200, response)
    assert_equal("1; mode=block", response.headers["X-XSS-Protection"])
    assert_equal("DENY", response.headers["X-Frame-Options"])
    assert_equal("nosniff", response.headers["X-Content-Type-Options"])
  end

  def test_headers_from_website_backends_take_precendence
    prepend_website_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_protocol => "http",
        :server_host => "127.0.0.1",
        :server_port => 9443,
      },
    ])

    response = Typhoeus.get("https://127.0.0.1:9081/allow-frame/", keyless_http_options.deep_merge({
      :headers => {
        "Host" => unique_test_hostname,
      },
    }))
    assert_response_code(200, response)
    assert_match("frame", response.body)
    assert_equal("1; mode=block", response.headers["X-XSS-Protection"])
    assert_equal("ALLOWALL", response.headers["X-Frame-Options"])
    assert_equal("nosniff", response.headers["X-Content-Type-Options"])
  end

  def test_does_not_add_security_headers_to_apis
    response = Typhoeus.get("https://127.0.0.1:9081/api/hello", http_options)
    assert_response_code(200, response)
    assert_nil(response.headers["X-XSS-Protection"])
    assert_nil(response.headers["X-Frame-Options"])
    assert_nil(response.headers["X-Content-Type-Options"])
  end
end
