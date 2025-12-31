require_relative "../test_helper"

class Test::Apis::TestWebAppErrorHandling < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_not_found_route
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/test-404", http_options.deep_merge(admin_token))
    assert_response_code(404, response)
    assert_equal("<html>\n  <head><title>404 Not Found</title></head>\n  <body bgcolor=\"white\">\n    <center><h1>404 Not Found</h1></center>\n    <hr><center>API Umbrella</center>\n  </body>\n</html>\n", response.body)
    assert_no_backtrace(response)
  end

  def test_unexpected_error
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/test-500", http_options.deep_merge(admin_token))
    assert_response_code(500, response)
    assert_equal("<html>\n  <head><title>500 Internal Server Error</title></head>\n  <body bgcolor=\"white\">\n    <center><h1>500 Internal Server Error</h1></center>\n    <hr><center>API Umbrella</center>\n  </body>\n</html>\n", response.body)
    assert_no_backtrace(response)
  end

  private

  def assert_no_backtrace(response)
    # Verify that there's no Lapis HTTP header showing the backtrace (even when
    # the body is set to something custom).
    refute(response.headers["X-Lapis-Error"])

    # Verify that there's no backtrace details anywhere else in other headers
    # or in the body.
    [
      response.body,
      response.headers.to_s,
    ].each do |text|
      refute_match(".lua", text)
      refute_match("trace", text)
      refute_match("stack", text)
    end
  end
end
