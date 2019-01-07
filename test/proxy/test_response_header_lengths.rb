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
        :header_length => 7900,
        :header_count => 1,
      },
    }))

    assert_response_code(200, response)
    assert_equal(7900, response.headers.fetch("X-Foo1").bytesize)
    assert_operator(response.response_headers.bytesize, :>, 8100)
    assert_operator(response.response_headers.bytesize, :<, 8192)
  end

  def test_multiple_headers_less_than_8k
    response = Typhoeus.get("http://127.0.0.1:9080/api/response-headers-length/", http_options.deep_merge({
      :params => {
        :header_length => 100,
        :header_count => 71,
      },
    }))

    assert_response_code(200, response)
    assert_equal(100, response.headers.fetch("X-Foo1").bytesize)
    assert_equal(100, response.headers.fetch("X-Foo2").bytesize)
    assert_equal(100, response.headers.fetch("X-Foo70").bytesize)
    assert_equal(100, response.headers.fetch("X-Foo71").bytesize)
    assert_operator(response.response_headers.bytesize, :>, 8100)
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
        :header_length => 100,
        :header_count => 73,
      },
    }))

    assert_response_code(502, response)
  end
end
