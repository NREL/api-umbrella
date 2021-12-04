require_relative "../test_helper"

class Test::Proxy::TestMultipleRequestHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_receives_single_header_for_accept
    assert_receives_single_comma_delimited_header("Accept")
  end

  def test_receives_single_header_for_content_type
    assert_receives_single_comma_delimited_header("Content-Type")
  end

  def test_receives_single_header_for_origin
    assert_receives_single_comma_delimited_header("Origin")
  end

  def test_receives_single_header_for_referer
    assert_receives_single_comma_delimited_header("Referer")
  end

  def test_receives_single_header_for_user_agent
    assert_receives_single_comma_delimited_header("User-Agent")
  end

  def test_receives_single_header_for_via
    assert_receives_single_comma_delimited_header("Via")
  end

  def test_receives_single_header_for_cookie
    assert_receives_single_semicolon_delimited_header("Cookie")
  end

  def test_receives_multiple_headers_for_unknown_header
    assert_receives_multiple_headers("Foo")
  end

  def test_receives_multiple_headers_for_custom_header
    assert_receives_multiple_headers("X-Foo")
  end

  private

  def request_with_duplicate_headers(header)
    # Drop-down to a lower-level mechanism for setting the headers, so we can
    # set duplicate headers for the same header name (the default `:headers`
    # hash approach can't set multiple headers).
    header_list = nil
    header_list = Ethon::Curl.slist_append(header_list, "X-Api-Key: #{api_key}")
    header_list = Ethon::Curl.slist_append(header_list, "X-Api-Umbrella-Test-Return-Request-Id: true")
    header_list = Ethon::Curl.slist_append(header_list, "#{header}: 11")
    header_list = Ethon::Curl.slist_append(header_list, "#{header}: 22")
    response = Typhoeus.get("http://127.0.0.1:9080/api/logging-multiple-request-headers/", keyless_http_options.deep_merge({
      :params => {
        :header => header,
      },
      :headers => {},
      :httpheader => header_list,
      :verbose => true,
    }))
    assert_response_code(200, response)

    # Verify that our outbound request included 2 distinct headers.
    assert_equal(2, response.debug_info.header_out.join("").scan(/^#{header}: /).length)

    response
  end

  def assert_receives_single_comma_delimited_header(header)
    response = request_with_duplicate_headers(header)

    data = MultiJson.load(response.body)
    assert_equal("11,22", data["header_value"])
    assert_equal(1, data["header_occurrences_received"])
  end

  def assert_receives_single_semicolon_delimited_header(header)
    response = request_with_duplicate_headers(header)

    data = MultiJson.load(response.body)
    assert_equal("11; 22", data["header_value"])
    assert_equal(1, data["header_occurrences_received"])
  end

  def assert_receives_multiple_headers(header)
    response = request_with_duplicate_headers(header)

    data = MultiJson.load(response.body)
    assert_equal(["11", "22"], data["header_value"])
    assert_equal(2, data["header_occurrences_received"])
  end
end
