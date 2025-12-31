require_relative "../../test_helper"

class Test::Proxy::ResponseRewriting::TestResponseHeadersTestOnly < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_debug_workers
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options)
    assert_response_code(200, response)
    refute(response.headers["x-api-umbrella-test-worker-id"])
    refute(response.headers["x-api-umbrella-test-worker-count"])
    refute(response.headers["x-api-umbrella-test-worker-pid"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :headers => {
        "X-Api-Umbrella-Test-Debug-Workers" => "true",
      },
    }))
    assert_response_code(200, response)
    assert(response.headers["x-api-umbrella-test-worker-id"])
    assert(response.headers["x-api-umbrella-test-worker-count"])
    assert(response.headers["x-api-umbrella-test-worker-pid"])
  end

  # Previously, the "X-Api-Umbrella-Test-Return-Request-Id" header would return
  # a "X-Api-Umbrella-Test-Request-Id" header, but this is no longer needed now
  # that we return the "X-Api-Umbrella-Request-Id" header on all responses.
  def test_request_id
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options)
    assert_response_code(200, response)
    assert(response.headers["x-api-umbrella-request-id"])
    refute(response.headers["x-api-umbrella-test-request-id"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", http_options.deep_merge({
      :headers => {
        "X-Api-Umbrella-Test-Return-Request-Id" => "true",
      },
    }))
    assert_response_code(200, response)
    assert(response.headers["x-api-umbrella-request-id"])
    refute(response.headers["x-api-umbrella-test-request-id"])
  end
end
