require_relative "../../test_helper"

class Test::Proxy::Logging::TestRequestHeadersMultipleValues < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_logs_first_value_for_content_type
    assert_logs_first_value("Content-Type", "request_content_type", :inline_header => true)
  end

  def test_logs_first_value_for_invalid_referer
    assert_logs_first_value("Referer", "request_referer", :inline_header => true)
  end

  def test_logs_first_value_for_valid_referer
    assert_logs_first_value("Referer", "request_referer", :inline_header => true, :first_value => "https://example.com/11", :second_value => "https://example.com/22")
  end

  def test_logs_first_value_for_user_agent
    assert_logs_first_value("User-Agent", "request_user_agent", :inline_header => true)
  end

  def test_logs_all_values_for_accept
    assert_logs_all_values("Accept", "request_accept", :inline_header => true)
  end

  def test_logs_all_values_for_accept_encoding
    assert_logs_all_values("Accept-Encoding", "request_accept_encoding", :cleared_by_proxy => true)
  end

  def test_logs_all_values_for_connection
    assert_logs_all_values("Connection", "request_connection", :cleared_by_proxy => true)
  end

  def test_logs_all_values_for_origin
    assert_logs_all_values("Origin", "request_origin", :inline_header => true)
  end

  # These headers should technically be tested too, but they"re difficult to
  # test since HTTP clients and servers don't want to set multiple values. So
  # for now, we"ll assume these are being properly handled in
  # src/api-umbrella/utils/flatten_headers.lua.
  def test_logs_first_value_for_authorization
    skip "Can't easily test, verify in code"
    # assert_logs_first_value("Authorization", "request_basic_auth_username")
  end

  def test_logs_first_value_for_host
    skip "Can't easily test, verify in code"
    # assert_logs_first_value("Host", "request_host")
  end

  private

  def request_with_duplicate_headers(header, inline_header: false, cleared_by_proxy: false, first_value: "11", second_value: "22")
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

    # Verify that the request received by the API backend contained 2 distinct
    # headers, except in the cases where we overwrite the header during
    # proxying or in cases where Envoy collapses standard headers to a single
    # comma-delimited header (which should be safe for these standard headers).
    data = MultiJson.load(response.body)
    if cleared_by_proxy
      assert_nil(data["header_value"])
      assert_equal(0, data["header_occurrences_received"])
    elsif inline_header
      assert_equal("#{first_value},#{second_value}", data["header_value"])
      assert_equal(1, data["header_occurrences_received"])
    else
      assert_equal([first_value, second_value], data["header_value"])
      assert_equal(2, data["header_occurrences_received"])
    end

    # Verify that our outbound request included 2 distinct headers.
    assert_equal(2, response.debug_info.header_out.join("").scan(/^#{header}: /).length)

    response
  end

  def assert_logs_first_value(header, log_field, inline_header: false, cleared_by_proxy: false, first_value: "11", second_value: "22")
    response = request_with_duplicate_headers(header, inline_header: inline_header, cleared_by_proxy: cleared_by_proxy, first_value: first_value, second_value: second_value)
    record = wait_for_log(response)[:hit_source]
    assert_equal(first_value, record[log_field])
  end

  def assert_logs_all_values(header, log_field, inline_header: false, cleared_by_proxy: false, first_value: "11", second_value: "22")
    response = request_with_duplicate_headers(header, inline_header: inline_header, cleared_by_proxy: cleared_by_proxy, first_value: first_value, second_value: second_value)
    record = wait_for_log(response)[:hit_source]
    assert_equal("#{first_value}, #{second_value}", record[log_field])
  end
end
