require_relative "../test_helper"

class Test::Proxy::TestResponseHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_expected_headers_on_proxied_requests
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/", http_options)

    assert_response_code(200, response)
    assert_equal([
      "Age",
      "Connection",
      "Date",
      "Server",
      "Transfer-Encoding",
      "Via",
      "X-Api-Umbrella-Request-ID",
      "X-Cache",
    ].sort, response.headers.keys.sort)
    assert_equal("0", response.headers["Age"])
    assert_equal("keep-alive", response.headers["Connection"])
    assert_equal("openresty", response.headers["Server"])
    assert_equal("chunked", response.headers["Transfer-Encoding"])
    assert_equal("http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])", response.headers["Via"])
    assert_match(/\A[a-z0-9]{20}\z/, response.headers["X-Api-Umbrella-Request-ID"])
    assert_equal("MISS", response.headers["X-Cache"])
  end

  def test_expected_headers_on_blocked_requests
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/", keyless_http_options)

    assert_response_code(403, response)
    assert_equal([
      "Access-Control-Allow-Origin",
      "Connection",
      "Content-Type",
      "Date",
      "Server",
      "Transfer-Encoding",
      "Vary",
      "X-Api-Umbrella-Request-ID",
      "X-Cache",
      "X-Content-Type-Options",
      "X-Frame-Options",
      "X-XSS-Protection",
    ].sort, response.headers.keys.sort)
    assert_equal("*", response.headers["Access-Control-Allow-Origin"])
    assert_equal("keep-alive", response.headers["Connection"])
    assert_equal("application/json", response.headers["Content-Type"])
    assert_equal("openresty", response.headers["Server"])
    assert_equal("chunked", response.headers["Transfer-Encoding"])
    assert_equal("Accept-Encoding", response.headers["Vary"])
    assert_match(/\A[a-z0-9]{20}\z/, response.headers["X-Api-Umbrella-Request-ID"])
    assert_equal("MISS", response.headers["X-Cache"])
    assert_equal("nosniff", response.headers["X-Content-Type-Options"])
    assert_equal("DENY", response.headers["X-Frame-Options"])
    assert_equal("1; mode=block", response.headers["X-XSS-Protection"])
  end
end
