require_relative "../../test_helper"

class Test::Proxy::Logging::TestRequestHeadersMultipleValues < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  MULTIPLE_FORBIDDEN = {
    "Content-Type" => "request_content_type",
    "Referer" => "request_referer",
    "User-Agent" => "request_user_agent",

    # These headers should technically be tested too, but they"re difficult to
    # test since HTTP clients and servers don"t want to set multiple values. So
    # for now, we"ll assume these are being properly handled in
    # src/api-umbrella/utils/flatten_headers.lua.
    #
    # "Authorization" => "request_basic_auth_username",
    # "Host" => "request_host",
  }.freeze

  MULTIPLE_ALLOWED = {
    "Accept" => "request_accept",
    "Accept-Encoding" => "request_accept_encoding",
    "Connection" => "request_connection",
    "Origin" => "request_origin",
  }.freeze

  MULTIPLE_OVERRIDEN_INSIDE_PROXY = [
    "Accept-Encoding",
    "Connection",
  ].freeze

  def setup
    super
    setup_server
  end

  MULTIPLE_FORBIDDEN.each do |header, log_field|
    header_method_name = header.to_s.downcase.gsub(/[^\w]/, "_")
    define_method("test_logs_first_value_for_#{header_method_name}") do
      response = request_with_duplicate_headers(header)
      record = wait_for_log(response)[:hit_source]
      assert_equal("11", record[log_field])
    end
  end

  MULTIPLE_ALLOWED.each do |header, log_field|
    header_method_name = header.to_s.downcase.gsub(/[^\w]/, "_")
    define_method("test_logs_all_values_for_#{header_method_name}") do
      response = request_with_duplicate_headers(header)
      record = wait_for_log(response)[:hit_source]
      assert_equal("11, 22", record[log_field])
    end
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

    # Verify that the request received by the API backend contained 2 distinct
    # headers, except in the cases where we overwrite the header during proxying.
    data = MultiJson.load(response.body)
    if(MULTIPLE_OVERRIDEN_INSIDE_PROXY.include?(header))
      assert_equal(0, data["header_occurrences_received"])
    else
      assert_equal(2, data["header_occurrences_received"])
      assert_equal(["11", "22"], data["header_value"])
    end

    response
  end
end
