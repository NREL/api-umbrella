require_relative "../test_helper"

class Test::Proxy::TestHttpMethods < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_get_requests
    test_request_without_body("GET")
  end

  def test_head_requests
    test_request_without_body("HEAD")
  end

  def test_delete_requests
    test_request_without_body("DELETE")
  end

  def test_post_requests_with_body
    test_request_with_body("POST")
  end

  def test_post_requests_with_chunked_body
    test_request_with_chunked_body("POST")
  end

  def test_put_requests_with_body
    test_request_with_body("PUT")
  end

  def test_put_requests_with_chunked_body
    test_request_with_chunked_body("PUT")
  end

  def test_patch_requests_with_body
    test_request_with_body("PATCH")
  end

  def test_patch_requests_with_chunked_body
    test_request_with_chunked_body("PATCH")
  end

  def test_options_requests_without_body
    test_request_without_body("OPTIONS")
  end

  def test_options_requests_with_body
    test_request_with_body("OPTIONS")
  end

  def test_options_requests_with_chunked_body
    test_request_with_chunked_body("OPTIONS")
  end

  def test_trace_requests
    response = Typhoeus::Request.new("http://127.0.0.1:9080/api/info/", http_options.deep_merge(:method => "TRACE")).run

    assert_response_code(405, response)
  end

  private

  def test_request_without_body(method)
    response = Typhoeus::Request.new("http://127.0.0.1:9080/api/info/", http_options.deep_merge(:method => method)).run

    assert_response_code(200, response)
    assert_equal(method, response.headers["X-Received-Method"])
  end

  def test_request_with_body(method)
    response = Typhoeus::Request.new("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :method => method,
      :body => "test",
    })).run

    assert_response_code(200, response)
    assert_equal(method, response.headers["X-Received-Method"])
  end

  def test_request_with_chunked_body(method)
    response = Typhoeus::Request.new("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :method => method,
      :body => "test",
      :headers => {
        "Transfer-Encoding" => "chunked",
      },
    })).run

    assert_response_code(200, response)
    assert_equal(method, response.headers["X-Received-Method"])
  end
end
