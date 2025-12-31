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

  def test_receives_no_headers_for_invalid_referer
    assert_receives_single_comma_delimited_header("Referer")
  end

  def test_receives_single_header_for_valid_referer
    assert_receives_single_comma_delimited_header("Referer", first_value: "https://example.com/11", second_value: "https://example.com/22")
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

  def request_with_duplicate_headers(header, first_value: "11", second_value: "22")
    # Drop-down to a lower-level mechanism for setting the headers, so we can
    # set duplicate headers for the same header name (the default `:headers`
    # hash approach can't set multiple headers).
    header_list = nil
    header_list = Ethon::Curl.slist_append(header_list, "X-Api-Key: #{api_key}")
    header_list = Ethon::Curl.slist_append(header_list, "X-Api-Umbrella-Test-Return-Request-Id: true")
    header_list = Ethon::Curl.slist_append(header_list, "#{header}: #{first_value}")
    header_list = Ethon::Curl.slist_append(header_list, "#{header}: #{second_value}")
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

  def assert_receives_single_comma_delimited_header(header, first_value: "11", second_value: "22")
    response = request_with_duplicate_headers(header, first_value: first_value, second_value: second_value)

    data = MultiJson.load(response.body)
    assert_equal("#{first_value},#{second_value}", data["header_value"])
    assert_equal(1, data["header_occurrences_received"])
  end

  def assert_receives_single_semicolon_delimited_header(header, first_value: "11", second_value: "22")
    response = request_with_duplicate_headers(header, first_value: first_value, second_value: second_value)

    data = MultiJson.load(response.body)
    assert_equal("#{first_value}; #{second_value}", data["header_value"])
    assert_equal(1, data["header_occurrences_received"])
  end

  def assert_receives_multiple_headers(header, first_value: "11", second_value: "22")
    response = request_with_duplicate_headers(header, first_value: first_value, second_value: second_value)

    data = MultiJson.load(response.body)
    assert_equal([first_value, second_value], data["header_value"])
    assert_equal(2, data["header_occurrences_received"])
  end

  def assert_receives_no_headers(header, first_value: "11", second_value: "22")
    response = request_with_duplicate_headers(header, first_value: first_value, second_value: second_value)

    data = MultiJson.load(response.body)
    assert_nil(data["header_value"])
    assert_equal(0, data["header_occurrences_received"])
  end
end
