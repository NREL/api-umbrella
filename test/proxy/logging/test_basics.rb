require_relative "../../test_helper"

class Test::Proxy::Logging::TestBasics < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_logs_expected_fields_for_non_chunked_non_gzip
    param_url1 = "http%3A%2F%2Fexample.com%2F%3Ffoo%3Dbar%26foo%3Dbar%20more+stuff"
    param_url2 = "%ED%A1%BC"
    param_url3_prefix = "https%3A//example.com/foo/"
    param_url3_invalid_suffix = "%D6%D0%B9%FA%BD%AD%CB%D5%CA%A1%B8%D3%D3%DC%CF%D8%D2%BB%C2%A5%C5%CC%CA%C0%BD%F5%BB%AA%B3%C7200%D3%E0%D2%B5%D6%F7%B9%BA%C2%F2%B5%C4%C9%CC%C6%B7%B7%BF%A3%AC%D2%F2%BF%AA%B7%A2%C9%CC%C5%DC%C2%B7%D2%D1%CD%A3%B9%A420%B8%F6%D4%C2%A3%AC%D2%B5%D6%F7%C4%C3%B7%BF%CE%DE%CD%FB%C8%B4%D0%E8%BC%CC%D0%F8%B3%A5%BB%B9%D2%F8%D0%D0%B4%FB%BF%EE%A1%A3%CF%F2%CA%A1%CA%D0%CF%D8%B9%FA%BC%D2%D0%C5%B7%C3%BE%D6%B7%B4%D3%B3%BD%FC2%C4%EA%CE%DE%C8%CB%B4%A6%C0%ED%A1%A3%D4%DA%B4%CB%B0%B8%D6%D0%A3%AC%CE%D2%C3%C7%BB%B3%D2%C9%D3%D0%C8%CB%CA%A7%D6%B0%E4%C2%D6%B0/sites/default/files/googleanalytics/ga.js"
    param_url3 = param_url3_prefix + param_url3_invalid_suffix

    url = "http://127.0.0.1:9080/api/logging-example/foo/bar/?url1=#{param_url1}&url2=#{param_url2}&url3=#{param_url3}"
    response = Typhoeus.get(url, log_http_options.deep_merge({
      :headers => {
        "Accept" => "text/plain; q=0.5, text/html",
        "Accept-Encoding" => "compress, gzip",
        "Connection" => "close",
        "Content-Type" => "application/x-www-form-urlencoded",
        "Origin" => "http://foo.example",
        "User-Agent" => "curl/7.37.1",
        "Referer" => "http://example.com",
        "X-Forwarded-For" => "1.2.3.4, 4.5.6.7, 10.10.10.11, 10.10.10.10, 192.168.12.0, 192.168.13.255",
      },
      :userpwd => "basic-auth-username-example:my-secret-password",
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]

    assert_equal([
      "api_backend_id",
      "api_backend_url_match_id",
      "api_key",
      "request_accept",
      "request_accept_encoding",
      "request_at",
      "request_basic_auth_username",
      "request_connection",
      "request_content_type",
      "request_hierarchy",
      "request_host",
      "request_ip",
      "request_method",
      "request_origin",
      "request_path",
      "request_referer",
      "request_scheme",
      "request_size",
      "request_url",
      "request_url_query",
      "request_user_agent",
      "request_user_agent_family",
      "request_user_agent_type",
      "response_age",
      "response_cache",
      "response_content_length",
      "response_content_type",
      "response_server",
      "response_size",
      "response_status",
      "response_time",
      "user_email",
      "user_id",
      "user_registration_source",
    ].sort, record.keys.sort)

    assert_kind_of(String, record["api_backend_id"])
    assert_kind_of(String, record["api_backend_url_match_id"])
    assert_equal(self.api_key, record["api_key"])
    assert_equal("text/plain; q=0.5, text/html", record["request_accept"])
    assert_equal("compress, gzip", record["request_accept_encoding"])
    assert_kind_of(Numeric, record["request_at"])
    assert_match(/\A\d{13}\z/, record["request_at"].to_s)
    assert_equal("basic-auth-username-example", record["request_basic_auth_username"])
    assert_equal("close", record["request_connection"])
    assert_equal("application/x-www-form-urlencoded", record["request_content_type"])
    assert_equal([
      "0/127.0.0.1:9080/",
      "1/127.0.0.1:9080/api/",
      "2/127.0.0.1:9080/api/logging-example/",
      "3/127.0.0.1:9080/api/logging-example/foo/",
      "4/127.0.0.1:9080/api/logging-example/foo/bar",
    ], record["request_hierarchy"])
    assert_equal("127.0.0.1:9080", record["request_host"])
    assert_equal("10.10.10.11", record["request_ip"])
    assert_equal("GET", record["request_method"])
    assert_equal("http://foo.example", record["request_origin"])
    assert_equal("/api/logging-example/foo/bar/", record["request_path"])
    assert_equal("http://example.com", record["request_referer"])
    assert_equal("http", record["request_scheme"])
    assert_kind_of(Numeric, record["request_size"])
    assert_equal(url, record["request_url"])
    assert_equal("url1=#{param_url1}&url2=#{param_url2}&url3=#{param_url3}", record["request_url_query"])
    assert_equal("curl/7.37.1", record["request_user_agent"])
    assert_equal("cURL", record["request_user_agent_family"])
    assert_equal("Library", record["request_user_agent_type"])
    # The backend responds with an age of 20. The actual age might higher than
    # the original response if the response happens right on the boundary of a
    # second or the proxy is congested and the response is delayed.
    assert_operator(record["response_age"], :>=, 20)
    assert_operator(record["response_age"], :<=, 40)
    assert_equal("MISS", record["response_cache"])
    assert_equal("text/plain; charset=utf-8", record["response_content_type"])
    assert_equal("openresty", record["response_server"])
    assert_kind_of(Numeric, record["response_size"])
    assert_equal(200, record["response_status"])
    assert_kind_of(Numeric, record["response_time"])
    assert_kind_of(String, record["user_email"])
    assert_equal(self.api_user.email, record["user_email"])
    assert_kind_of(String, record["user_id"])
    assert_equal(self.api_user.id, record["user_id"])
    assert_equal("seed", record["user_registration_source"])
    assert_equal(5, record["response_content_length"])
  end

  def test_logs_extra_fields_for_chunked_or_gzip
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible-delayed-chunked/5", log_http_options.deep_merge({
      :accept_encoding => "gzip",
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("gzip", record["response_content_encoding"])
    assert_equal("chunked", record["response_transfer_encoding"])
  end

  def test_logs_accept_encoding_header_prior_to_normalization
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "Accept-Encoding" => "compress, gzip",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("compress, gzip", record["request_accept_encoding"])
  end

  def test_logs_external_connection_header_not_internal
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "Connection" => "close",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("close", record["request_connection"])
  end

  def test_logs_client_host_for_wildcard_domains
    prepend_api_backends([
      {
        :frontend_host => "*",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello", log_http_options.deep_merge({
        :headers => {
          "Host" => "unknown.foo",
        },
      }))
      assert_response_code(200, response)

      record = wait_for_log(response)[:hit_source]
      assert_equal("unknown.foo", record["request_host"])
    end
  end

  def test_logs_request_schema_for_direct_hits
    response = Typhoeus.get("https://127.0.0.1:9081/api/hello", log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("https", record["request_scheme"])
  end

  def test_logs_request_schema_from_forwarded_header
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Forwarded-Proto" => "https",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("https", record["request_scheme"])
  end

  # For Elasticsearch 2 compatibility
  def test_requests_with_dots_in_query_params
    url = "http://127.0.0.1:9080/api/hello?foo.bar.baz=example.1&foo.bar=example.2&foo[bar]=example.3"
    response = Typhoeus.get(url, log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_logged_url(url, record)
  end

  def test_requests_with_duplicate_query_params
    url = "http://127.0.0.1:9080/api/hello?test_dup_arg=foo&test_dup_arg=bar"
    response = Typhoeus.get(url, log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_logged_url(url, record)
  end

  def test_logs_request_at_as_date
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options)
    assert_response_code(200, response)

    hit = wait_for_log(response)[:hit]
    result = LogItem.gateway.client.indices.get_mapping({
      :index => hit["_index"],
      :type => hit["_type"],
    })

    property = result[hit["_index"]]["mappings"][hit["_type"]]["properties"]["request_at"]
    if($config["elasticsearch"]["api_version"] == 1)
      assert_equal({
        "type" => "date",
        "format" => "dateOptionalTime",
      }, property)
    elsif($config["elasticsearch"]["api_version"] >= 2)
      assert_equal({
        "type" => "date",
        "format" => "strict_date_optional_time||epoch_millis",
      }, property)
    else
      flunk("Unknown elasticsearch version: #{$config["elasticsearch"]["api_version"].inspect}")
    end
  end

  def test_logs_requests_that_time_out
    time_out_delay = $config["nginx"]["proxy_connect_timeout"] * 1000 + 3500
    response = Typhoeus.get("http://127.0.0.1:9080/api/delay/#{time_out_delay}", log_http_options)
    assert_response_code(504, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal(504, record["response_status"])
    assert_logs_base_fields(record, api_user)
    # Check that the logged response time is approximately what's expected.
    # Allow for some buffer, since the exact timing can be a bit fuzzy--we
    # mainly want to ensure it's how long the request was open before timing
    # out, rather than the response time of the underlying API (since it timed
    # out and was never completed).
    expected_timeout_response_time = $config["nginx"]["proxy_connect_timeout"] * 1000
    assert_in_delta(expected_timeout_response_time, record["response_time"], 2100)
    assert_operator(expected_timeout_response_time, :<, time_out_delay)
  end

  def test_logs_requests_that_are_canceled
    response = Typhoeus.get("http://127.0.0.1:9080/api/delay/2000", log_http_options.deep_merge({
      :timeout => 0.5,
    }))
    assert(response.timed_out?)

    record = wait_for_log(response, :lookup_by_unique_user_agent => true)[:hit_source]
    assert_equal(499, record["response_status"])
    assert_logs_base_fields(record, api_user)
  end

  def test_logs_cached_responses
    responses = Array.new(3) do
      response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-expires/#{unique_test_id}", log_http_options)
      assert_response_code(200, response)
      response
    end

    cache_results = {}
    responses.each do |response|
      record = wait_for_log(response)[:hit_source]
      assert_equal(200, record["response_status"])
      assert_logs_base_fields(record, api_user)
      assert_kind_of(Numeric, record["response_age"])
      cache_results[record["response_cache"]] ||= 0
      cache_results[record["response_cache"]] += 1
    end
    assert_equal({
      "MISS" => 1,
      "HIT" => 2,
    }, cache_results)
  end

  def test_logs_denied_requests
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "X-Api-Key" => "INVALID_KEY",
      },
    }))
    assert_response_code(403, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal(403, record["response_status"])
    assert_logs_base_fields(record)
    assert_equal("INVALID_KEY", record["api_key"])
    assert_equal("api_key_invalid", record["gatekeeper_denied_code"])
    refute(record["user_email"])
    refute(record["user_id"])
    refute(record["user_registration_source"])
  end

  def test_logs_requests_when_backend_is_down
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9450 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/down", :backend_prefix => "/down" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/down", log_http_options)
      assert_response_code(502, response)

      record = wait_for_log(response)[:hit_source]
      assert_equal(502, record["response_status"])
      assert_logs_base_fields(record, api_user)
    end
  end

  def test_logs_requests_with_maximum_8kb_url_limit
    url_path = "/api/hello?long="
    long_length = 8192 - "GET #{url_path} HTTP/1.1\r\n".length
    long_value = Faker::Lorem.characters(long_length)
    url = "http://127.0.0.1:9080#{url_path}#{long_value}"

    response = Typhoeus.get(url, log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("/api/hello", record["request_path"])
    assert_equal("long=#{long_value}"[0, 4000], record["request_url_query"])
  end

  # We may actually want to revisit this behavior and log these requests, but
  # documenting current behavior.
  #
  # In order to log these requests, we'd need to move the log_by_lua_file
  # statement out of the "location" block and into the "http" level. We'd then
  # need to account for certain things in the logging logic that won't be
  # present in these error conditions.
  def test_does_not_log_requests_exceeding_8kb_url_limit
    url_path = "/api/hello?long="
    long_length = 8193 - "GET #{url_path} HTTP/1.1\r\n".length
    long_value = Faker::Lorem.characters(long_length)
    url = "http://127.0.0.1:9080#{url_path}#{long_value}"

    response = Typhoeus.get(url, log_http_options)
    assert_response_code(414, response)

    error = assert_raises Timeout::Error do
      wait_for_log(response, :lookup_by_unique_user_agent => true, :timeout => 5)
    end
    assert_match("Log not found: ", error.message)
  end

  def test_truncates_url_path_length_in_logs
    long_path = "/api/hello/#{Faker::Lorem.characters(6000)}"
    response = Typhoeus.get("http://127.0.0.1:9080#{long_path}", log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_operator(long_path.length, :>, 4000)
    assert_equal(4000, record["request_path"].length)
    assert_equal(long_path[0, 4000], record["request_path"])
  end

  def test_truncates_url_query_length_in_logs
    long_query = "long=#{Faker::Lorem.characters(6000)}"
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?#{long_query}", log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_operator(long_query.length, :>, 4000)
    assert_equal(4000, record["request_url_query"].length)
    assert_equal(long_query[0, 4000], record["request_url_query"])
  end

  # Try to log a long version of all inputs to ensure the overall log message
  # doesn't exceed rsyslog's buffer size.
  def test_long_url_and_request_headers_and_response_headers
    # Setup a backend to accept wildcard hosts so we can test a long hostname.
    prepend_api_backends([
      {
        :frontend_host => "*",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      url_path = "/#{unique_test_id}/logging-long-response-headers/?long="
      long_length = 8192 - "GET #{url_path} HTTP/1.1\r\n".length
      long_value = Faker::Lorem.characters(long_length)
      url = "http://127.0.0.1:9080#{url_path}#{long_value}"

      long_host = Faker::Lorem.characters(1000)
      response = Typhoeus.get(url, log_http_options.deep_merge({
        :headers => {
          "Accept" => Faker::Lorem.characters(1000),
          "Accept-Encoding" => Faker::Lorem.characters(1000),
          "Connection" => Faker::Lorem.characters(1000),
          "Content-Type" => Faker::Lorem.characters(1000),
          "Host" => long_host,
          "Origin" => Faker::Lorem.characters(1000),
          "User-Agent" => Faker::Lorem.characters(1000),
          "Referer" => Faker::Lorem.characters(1000),
        },
        :userpwd => "#{Faker::Lorem.characters(1000)}:#{Faker::Lorem.characters(1000)}",
      }))
      assert_response_code(200, response)

      record = wait_for_log(response)[:hit_source]

      # Check the logged URL.
      assert_equal(long_host[0, 200], record["request_host"])
      assert_equal("/#{unique_test_id}/logging-long-response-headers/", record["request_path"])
      assert_equal("long=#{long_value}"[0, 4000], record["request_url_query"])

      # Ensure the long header values got truncated so we're not susceptible to
      # exceeding rsyslog's message buffers and we're also not storing an
      # unexpected amount of data for values users can pass in.
      assert_equal(200, record["request_accept"].length, record["request_accept"])
      assert_equal(200, record["request_accept_encoding"].length, record["request_accept_encoding"])
      assert_equal(200, record["request_connection"].length, record["request_connection"])
      assert_equal(200, record["request_content_type"].length, record["request_content_type"])
      assert_equal(200, record["request_host"].length, record["request_host"])
      assert_equal(200, record["request_origin"].length, record["request_origin"])
      assert_equal(400, record["request_user_agent"].length, record["request_user_agent"])
      assert_equal(200, record["request_referer"].length, record["request_referer"])
      assert_equal(200, record["response_content_encoding"].length, record["response_content_encoding"])
      assert_equal(200, record["response_content_type"].length, record["response_content_type"])
    end
  end

  def test_case_sensitivity
    # Setup a backend to accept wildcard hosts so we can test an uppercase hostname.
    prepend_api_backends([
      {
        :frontend_host => "*",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      url = "HTTP://127.0.0.1:9080/#{unique_test_id}/logging-example/FOO/BAR/?URL1=FOO"
      response = Typhoeus.get(url, log_http_options.deep_merge({
        :headers => {
          "Accept" => "TEXT/PLAIN",
          "Accept-Encoding" => "GZIP",
          "Connection" => "CLOSE",
          "Content-Type" => "APPLICATION/X-WWW-FORM-URLENCODED",
          "Host" => "FOOBAR.EXAMPLE",
          "Origin" => "HTTP://FOO.EXAMPLE",
          "User-Agent" => "CURL/7.37.1",
          "Referer" => "HTTP://EXAMPLE.COM",
          "X-Forwarded-For" => "0:0:0:0:0:FFFF:3434:76C0",
        },
        :userpwd => "BASIC-AUTH-USERNAME-EXAMPLE:MY-SECRET-PASSWORD",
      }))
      assert_response_code(200, response)

      record = wait_for_log(response)[:hit_source]

      # Explicitly lowercased fields.
      assert_equal("foobar.example", record["request_host"])
      assert_equal("::ffff:52.52.118.192", record["request_ip"])
      assert_equal("http", record["request_scheme"])

      # Explicitly uppercased fields.
      assert_equal("GET", record["request_method"])
      assert_equal("US", record["request_ip_country"])
      assert_equal("CA", record["request_ip_region"])

      # Everything else should retain original case.
      assert_equal(self.api_key, record["api_key"])
      assert_equal("TEXT/PLAIN", record["request_accept"])
      assert_equal("GZIP", record["request_accept_encoding"])
      assert_equal("CLOSE", record["request_connection"])
      assert_equal("BASIC-AUTH-USERNAME-EXAMPLE", record["request_basic_auth_username"])
      assert_equal("APPLICATION/X-WWW-FORM-URLENCODED", record["request_content_type"])
      assert_equal([
        "0/foobar.example/",
        "1/foobar.example/#{unique_test_id}/",
        "2/foobar.example/#{unique_test_id}/logging-example/",
        "3/foobar.example/#{unique_test_id}/logging-example/FOO/",
        "4/foobar.example/#{unique_test_id}/logging-example/FOO/BAR",
      ], record["request_hierarchy"])
      assert_equal("San Jose", record["request_ip_city"])
      assert_equal("HTTP://FOO.EXAMPLE", record["request_origin"])
      assert_equal("/#{unique_test_id}/logging-example/FOO/BAR/", record["request_path"])
      assert_equal("URL1=FOO", record["request_url_query"])
      assert_equal("HTTP://EXAMPLE.COM", record["request_referer"])
      assert_equal("CURL/7.37.1", record["request_user_agent"])
      assert_equal("cURL", record["request_user_agent_family"])
      assert_equal("Library", record["request_user_agent_type"])
      assert_equal("MISS", record["response_cache"])
      assert_equal("text/plain; charset=utf-8", record["response_content_type"])
    end
  end

  def test_does_not_website_backend_requests
    response = Typhoeus.get("https://127.0.0.1:9081/", log_http_options)
    assert_response_code(200, response)

    error = assert_raises Timeout::Error do
      wait_for_log(response, :timeout => 5)
    end
    assert_match("Log not found: ", error.message)
  end

  def test_does_not_log_web_app_requests
    FactoryGirl.create(:admin)
    response = Typhoeus.get("https://127.0.0.1:9081/admin/login", log_http_options)
    assert_response_code(200, response)

    error = assert_raises Timeout::Error do
      wait_for_log(response, :timeout => 5)
    end
    assert_match("Log not found: ", error.message)
  end

  def test_logs_matched_api_backend_id
    api_id = SecureRandom.uuid
    url_match_id = SecureRandom.uuid

    prepend_api_backends([
      {
        :_id => api_id,
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :_id => url_match_id, :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello", log_http_options)
      assert_response_code(200, response)

      record = wait_for_log(response)[:hit_source]
      assert_equal(api_id, record["api_backend_id"])
      assert_equal(url_match_id, record["api_backend_url_match_id"])
    end
  end
end
