require_relative "../test_helper"

class Test::Proxy::TestMultipleResponseHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_receives_single_header_for_access_control_allow_origin
    assert_receives_single_comma_delimited_header("Access-Control-Allow-Origin")
  end

  def test_receives_single_header_for_vary
    assert_receives_single_comma_delimited_header("Vary")
  end

  def test_receives_multiple_headers_for_set_cookie
    assert_receives_multiple_headers("Set-Cookie")
  end

  def test_receives_multiple_headers_for_x_cache
    assert_receives_multiple_headers("X-Cache")
  end

  def test_receives_multiple_headers_for_unknown_header
    assert_receives_multiple_headers("Foo")
  end

  def test_receives_multiple_headers_for_custom_header
    assert_receives_multiple_headers("X-Foo")
  end

  private

  def response_with_duplicate_headers(header)
    response = Typhoeus.get("http://127.0.0.1:9080/api/logging-multiple-response-headers/", http_options.deep_merge({
      :verbose => true,
      :params => {
        :header => header,
      },
    }))

    assert_response_code(200, response)
    [response, response.debug_info.header_in.join("")]
  end

  def assert_receives_single_comma_delimited_header(header)
    response, raw_response_headers = response_with_duplicate_headers(header)

    # Validate that in the raw HTTP response, the header was seen on only a
    # single line.
    assert_equal(1, raw_response_headers.scan(/^#{header}: /i).length)

    # Validate that the response from Typhoeus gives us a single string.
    header_value = response.headers[header]
    assert_kind_of(String, header_value)
    assert_equal("11,45", header_value)
  end

  def assert_receives_multiple_headers(header)
    response, raw_response_headers = response_with_duplicate_headers(header)

    # Validate that in the raw HTTP response, the header was seen on two
    # separate lines.
    assert_equal(2, raw_response_headers.scan(/^#{header}: /i).length)

    # Validate that the response from Typhoeus gives us an array.
    header_value = response.headers[header]
    assert_kind_of(Array, header_value)
    assert_equal(["11", "45"], header_value)
  end
end
