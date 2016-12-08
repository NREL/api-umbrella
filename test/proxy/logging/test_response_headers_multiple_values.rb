require_relative "../../test_helper"

class Test::Proxy::Logging::TestResponseHeadersMultipleValues < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  MULTIPLE_FORBIDDEN = {
    "Age" => "response_age",

    # These headers should technically be tested too, but they"re difficult to
    # test since HTTP clients and servers don"t want to set multiple values. So
    # for now, we"ll assume these are being properly handled in
    # src/api-umbrella/utils/flatten_headers.lua.
    #
    # "Content-Length" => "response_content_length",
    # "Content-Type" => "response_content_type",
  }.freeze

  MULTIPLE_ALLOWED = {
    "X-Cache" => "response_cache",

    # These headers should technically be tested too, but they"re difficult to
    # test since HTTP clients and servers don"t want to set multiple values. So
    # for now, we"ll assume these are being properly handled in
    # src/api-umbrella/utils/flatten_headers.lua.
    #
    # "Content-Encoding" => "response_content_encoding",
    # "Transfer-Encoding" => "response_transfer_encoding",
  }.freeze

  def setup
    setup_server
  end

  MULTIPLE_FORBIDDEN.each do |header, log_field|
    header_method_name = header.to_s.downcase.gsub(/[^\w]/, "_")
    define_method("test_logs_first_value_for_#{header_method_name}") do
      response, raw_response_headers = response_with_duplicate_headers(header)
      assert_equal(1, raw_response_headers.scan(/^#{header}: /).length)
      assert_equal("11", response.headers[header])

      record = wait_for_log(response)[:hit_source]
      assert_equal("11", record[log_field].to_s)
    end
  end

  MULTIPLE_ALLOWED.each do |header, log_field|
    header_method_name = header.to_s.downcase.gsub(/[^\w]/, "_")
    define_method("test_logs_all_values_for_#{header_method_name}") do
      response, raw_response_headers = response_with_duplicate_headers(header)
      assert_equal(2, raw_response_headers.scan(/^#{header}: /).length)
      assert_equal(["11", "22"], response.headers[header])

      record = wait_for_log(response)[:hit_source]
      assert_equal("11, 22", record[log_field])
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
