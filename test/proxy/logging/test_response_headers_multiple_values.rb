require_relative "../../test_helper"

class Test::Proxy::Logging::TestResponseHeadersMultipleValues < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_logs_first_value_for_age
    assert_logs_first_value("Age", "response_age")
  end

  def test_logs_all_values_for_x_cache
    assert_logs_all_values("X-Cache", "response_cache")
  end

  # These headers should technically be tested too, but they're difficult to
  # test since HTTP clients and servers don't want to set multiple values. So
  # for now, we'll assume these are being properly handled in
  # src/api-umbrella/utils/flatten_headers.lua.
  def test_logs_first_value_for_content_length
    skip "Can't easily test, verify in code"
    # assert_logs_first_value("Content-Length", "response_content_length")
  end

  def test_logs_first_value_for_content_type
    skip "Can't easily test, verify in code"
    # assert_logs_first_value("Content-Type", "response_content_type")
  end

  def test_logs_all_values_for_content_encoding
    skip "Can't easily test, verify in code"
    # assert_logs_all_value("Content-Encoding", "response_content_encoding")
  end

  def test_logs_all_values_for_transfer_encoding
    skip "Can't easily test, verify in code"
    # assert_logs_all_value("Transfer-Encoding", "response_transfer_encoding")
  end

  private

  def response_with_duplicate_headers(header)
    response = Typhoeus.get("http://127.0.0.1:9080/api/logging-multiple-response-headers/", log_http_options.deep_merge({
      :verbose => true,
      :params => {
        :header => header,
      },
    }))

    assert_response_code(200, response)
    [response, response.debug_info.header_in.join("")]
  end

  def assert_logs_first_value(header, log_field, inline_header: false)
    # The API backend returns a header with two values: "11" and "45". Make
    # sure only the first is present.
    response, raw_response_headers = response_with_duplicate_headers(header)

    # Validate that in the raw HTTP response, the header was seen on only a
    # single line.
    assert_equal(1, raw_response_headers.scan(/^#{header}: /i).length)

    # Validate that the response from Typhoeus gives us a single string.
    header_value = response.headers[header]
    assert_kind_of(String, header_value)
    if(header == "Age")
      # The Age header can be a bit finicky, since even though the backend
      # responded with "11" as the first value, the value returned to the
      # client may go up if the request happens right on the boundary of a
      # second, or parts of our stack are congested during this test (so the
      # response takes longer).
      #
      # So just ensure that the single value we got back was based on the
      # first value and not the second one.
      assert_operator(header_value.to_i, :>=, 11)
      assert_operator(header_value.to_i, :<, 30)
    else
      assert_equal("11", header_value)
    end

    record = wait_for_log(response)[:hit_source]
    assert_equal(header_value, record[log_field].to_s)
  end

  def assert_logs_all_values(header, log_field, inline_header: false, cleared_by_proxy: false)
    # The API backend returns a header with two values: "11" and "45". Make
    # sure both are present.
    response, raw_response_headers = response_with_duplicate_headers(header)

    # Validate that in the raw HTTP response, the header was seen on two
    # separate lines.
    assert_equal(2, raw_response_headers.scan(/^#{header}: /i).length)

    # Validate that the response from Typhoeus gives us an array.
    header_value = response.headers[header]
    assert_kind_of(Array, header_value)
    assert_equal(["11", "45"], header_value)

    record = wait_for_log(response)[:hit_source]
    assert_equal("11, 45", record[log_field])
  end
end
