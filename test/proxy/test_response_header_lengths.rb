require_relative "../test_helper"

class Test::Proxy::TestResponseHeaderLengths < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_individual_header_less_than_8k
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-headers-length/", http_options.deep_merge({
      :params => {
        :header_length => 7790,
        :header_count => 1,
      },
    }))

    assert_response_code(200, response)
    assert_equal(7790, response.headers.fetch("x-foo1").bytesize)
    assert_operator(response.response_headers.bytesize, :>, 8050)
    assert_operator(response.response_headers.bytesize, :<, 8192)
  end

  def test_multiple_headers_less_than_8k
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-headers-length/", http_options.deep_merge({
      :params => {
        :header_length => 50,
        :header_count => 127,
      },
    }))

    assert_response_code(200, response)
    assert_equal(50, response.headers.fetch("x-foo1").bytesize)
    assert_equal(50, response.headers.fetch("x-foo2").bytesize)
    assert_equal(50, response.headers.fetch("x-foo126").bytesize)
    assert_equal(50, response.headers.fetch("x-foo127").bytesize)
    assert_operator(response.response_headers.bytesize, :>, 8020)
    assert_operator(response.response_headers.bytesize, :<, 8192)
  end

  def test_individual_header_greater_than_8k
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-headers-length/", http_options.deep_merge({
      :params => {
        :header_length => 8000,
        :header_count => 1,
      },
    }))

    assert_response_code(502, response)
  end

  def test_multiple_headers_greater_than_8k
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-headers-length/", http_options.deep_merge({
      :params => {
        :header_length => 50,
        :header_count => 131,
      },
    }))

    assert_response_code(502, response)
  end

  def test_accepts_below_max_response_headers_count
    # Envoy's maximum number of response HTTP headers is set to 200. But due to
    # other headers that may be part of the original response (eg, "Date",
    # "Transfer-Encoding"), the actual limit of custom headers sent by our API
    # backend may be lower. Plus, the nginx layer may add other headers to the
    # response, so the exact number of headers may also vary, which is why
    # we're leaving this imprecise.
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-headers-length/", http_options.deep_merge({
      :params => {
        :header_length => 2,
        :header_count => 196,
      },
    }))

    assert_response_code(200, response)
    assert_equal(204, response.headers.length)
  end

  def test_rejects_above_max_response_headers_count
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-headers-length/", http_options.deep_merge({
      :params => {
        :header_length => 2,
        :header_count => 197,
      },
    }))

    assert_response_code(502, response)
    assert_match("upstream connect error or disconnect/reset before headers. retried and the latest reset reason: protocol error", response.body)
  end
end
