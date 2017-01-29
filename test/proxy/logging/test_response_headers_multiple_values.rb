require_relative "../../test_helper"

class Test::Proxy::Logging::TestResponseHeadersMultipleValues < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  MULTIPLE_FORBIDDEN = {
    "Age" => "response_age",

    # These headers should technically be tested too, but they're difficult to
    # test since HTTP clients and servers don't want to set multiple values. So
    # for now, we'll assume these are being properly handled in
    # src/api-umbrella/utils/flatten_headers.lua.
    #
    # "Content-Length" => "response_content_length",
    # "Content-Type" => "response_content_type",
  }.freeze

  MULTIPLE_ALLOWED = {
    "X-Cache" => "response_cache",

    # These headers should technically be tested too, but they're difficult to
    # test since HTTP clients and servers don't want to set multiple values. So
    # for now, we'll assume these are being properly handled in
    # src/api-umbrella/utils/flatten_headers.lua.
    #
    # "Content-Encoding" => "response_content_encoding",
    # "Transfer-Encoding" => "response_transfer_encoding",
  }.freeze

  def setup
    super
    setup_server
  end

  MULTIPLE_FORBIDDEN.each do |header, log_field|
    header_method_name = header.to_s.downcase.gsub(/[^\w]/, "_")
    define_method("test_logs_first_value_for_#{header_method_name}") do
      # The API backend returns a header with two values: "11" and "45". Make
      # sure only the first is present.
      response, raw_response_headers = response_with_duplicate_headers(header)

      # Validate that in the raw HTTP response, the header was seen on only a
      # single line.
      assert_equal(1, raw_response_headers.scan(/^#{header}: /).length)

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
  end

  MULTIPLE_ALLOWED.each do |header, log_field|
    header_method_name = header.to_s.downcase.gsub(/[^\w]/, "_")
    define_method("test_logs_all_values_for_#{header_method_name}") do
      # The API backend returns a header with two values: "11" and "45". Make
      # sure both are present.
      response, raw_response_headers = response_with_duplicate_headers(header)

      # Validate that in the raw HTTP response, the header was seen on two
      # separate lines.
      assert_equal(2, raw_response_headers.scan(/^#{header}: /).length)

      # Validate that the response from Typhoeus gives us an array.
      header_value = response.headers[header]
      assert_kind_of(Array, header_value)
      assert_equal(["11", "45"], header_value)

      record = wait_for_log(response)[:hit_source]
      assert_equal("11, 45", record[log_field])
    end
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
end
