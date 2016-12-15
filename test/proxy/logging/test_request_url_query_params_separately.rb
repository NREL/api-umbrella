require_relative "../../test_helper"

class Test::Proxy::Logging::TestRequestUrlQueryParamsSeparately < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  include Minitest::Hooks

  def setup
    setup_server
    once_per_class_setup do
      override_config_set({
        :analytics => {
          :log_request_url_query_params_separately => true,
        },
      }, "--router")
    end
  end

  def after_all
    super
    override_config_reset("--router")
  end

  def test_encoding
    param_url1 = "http%3A%2F%2Fexample.com%2F%3Ffoo%3Dbar%26foo%3Dbar%20more+stuff"
    param_url2 = "%ED%A1%BC"
    param_url3_prefix = "https%3A//example.com/foo/"
    param_url3_invalid_suffix = "%D6%D0%B9%FA%BD%AD%CB%D5%CA%A1%B8%D3%D3%DC%CF%D8%D2%BB%C2%A5%C5%CC%CA%C0%BD%F5%BB%AA%B3%C7200%D3%E0%D2%B5%D6%F7%B9%BA%C2%F2%B5%C4%C9%CC%C6%B7%B7%BF%A3%AC%D2%F2%BF%AA%B7%A2%C9%CC%C5%DC%C2%B7%D2%D1%CD%A3%B9%A420%B8%F6%D4%C2%A3%AC%D2%B5%D6%F7%C4%C3%B7%BF%CE%DE%CD%FB%C8%B4%D0%E8%BC%CC%D0%F8%B3%A5%BB%B9%D2%F8%D0%D0%B4%FB%BF%EE%A1%A3%CF%F2%CA%A1%CA%D0%CF%D8%B9%FA%BC%D2%D0%C5%B7%C3%BE%D6%B7%B4%D3%B3%BD%FC2%C4%EA%CE%DE%C8%CB%B4%A6%C0%ED%A1%A3%D4%DA%B4%CB%B0%B8%D6%D0%A3%AC%CE%D2%C3%C7%BB%B3%D2%C9%D3%D0%C8%CB%CA%A7%D6%B0%E4%C2%D6%B0/sites/default/files/googleanalytics/ga.js"
    param_url3 = param_url3_prefix + param_url3_invalid_suffix

    url = "http://127.0.0.1:9080/api/logging-example/foo/bar/?url1=#{param_url1}&url2=#{param_url2}&url3=#{param_url3}&api_key=#{api_key}"
    response = Typhoeus.get(url, log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal(url, record["request_url"])
    assert_kind_of(Hash, record["request_query"])
    assert_equal([
      "api_key",
      "url1",
      "url2",
      "url3",
    ].sort, record["request_query"].keys.sort)
    assert_equal(api_key, record["request_query"]["api_key"])
    assert_equal(CGI.unescape(param_url1), record["request_query"]["url1"])
    assert_equal(param_url2, record["request_query"]["url2"])
    assert_equal(CGI.unescape(param_url3_prefix) + param_url3_invalid_suffix, record["request_query"]["url3"])
  end

  # For Elasticsearch 2 compatibility
  def test_requests_with_dots_in_query_params
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :params => {
        "foo.bar.baz" => "example.1",
        "foo.bar" => "example.2",
        "foo[bar]" => "example.3",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("example.1", record["request_query"]["foo_bar_baz"])
    assert_equal("example.2", record["request_query"]["foo_bar"])
    assert_equal("example.3", record["request_query"]["foo[bar]"])
  end

  def test_requests_with_duplicate_query_params
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?test_dup_arg=foo&test_dup_arg=bar", log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("foo,bar", record["request_query"]["test_dup_arg"])
  end

  # Does not attempt to automatically map the first seen value into a date.
  def test_dates_in_query_params_treated_as_strings
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :params => {
        :date_field => "2010-05-01",
      },
    }))
    assert_response_code(200, response)
    record = wait_for_log(response)[:hit_source]
    assert_equal("2010-05-01", record["request_query"]["date_field"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :params => {
        :date_field => "2010-05-0",
      },
    }))
    assert_response_code(200, response)
    record = wait_for_log(response)[:hit_source]
    assert_equal("2010-05-0", record["request_query"]["date_field"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :params => {
        :date_field => "foo",
      },
    }))
    assert_response_code(200, response)
    record = wait_for_log(response)[:hit_source]
    assert_equal("foo", record["request_query"]["date_field"])
  end

  # Does not attempt to automatically map the values into an array, which would
  # conflict with the first-seen string type.
  def test_duplicate_query_params_treated_as_strings
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?test_dup_arg_first_string=foo", log_http_options)
    assert_response_code(200, response)
    record = wait_for_log(response)[:hit_source]
    assert_equal("foo", record["request_query"]["test_dup_arg_first_string"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?test_dup_arg_first_string=foo&test_dup_arg_first_string=bar", log_http_options)
    assert_response_code(200, response)
    record = wait_for_log(response)[:hit_source]
    assert_equal("foo,bar", record["request_query"]["test_dup_arg_first_string"])
  end

  # Does not attempt to automatically map the first seen value into a boolean.
  def test_boolean_query_params_treated_as_strings
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?test_arg_first_bool", log_http_options)
    assert_response_code(200, response)
    record = wait_for_log(response)[:hit_source]
    assert_equal("true", record["request_query"]["test_arg_first_bool"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?test_arg_first_bool=foo", log_http_options)
    assert_response_code(200, response)
    record = wait_for_log(response)[:hit_source]
    assert_equal("foo", record["request_query"]["test_arg_first_bool"])
  end

  # Does not attempt to automatically map the first seen value into a number.
  def test_numbers_in_query_params_treated_as_strings
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :params => {
        :number_field => "123",
      },
    }))
    assert_response_code(200, response)
    record = wait_for_log(response)[:hit_source]
    assert_equal("123", record["request_query"]["number_field"])

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :params => {
        :number_field => "foo",
      },
    }))
    assert_response_code(200, response)
    record = wait_for_log(response)[:hit_source]
    assert_equal("foo", record["request_query"]["number_field"])
  end

  def test_valid_utf8_encoding_in_url_path_url_params_headers
    # Test various encodings of the UTF-8 pound symbol: £
    url_encoded = "%C2%A3"
    base64ed = "wqM="
    raw = "£"
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{raw}/?url_encoded=#{url_encoded}&base64ed=#{base64ed}&raw=#{raw}", log_http_options.deep_merge({
      :headers => {
        "Content-Type" => url_encoded,
        "Referer" => base64ed,
        "Origin" => raw,
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]

    # When in the URL path or query string, we expect the raw £ symbol to be
    # logged as the url encoded version.
    expected_raw_in_url = url_encoded

    # URL query string
    assert_equal(url_encoded, record["request_query"]["url_encoded"])
    assert_equal(base64ed, record["request_query"]["base64ed"])
    assert_equal(expected_raw_in_url, record["request_query"]["raw"])
  end

  def test_invalid_utf8_encoding
    # Test various encodings of the ISO-8859-1 pound symbol: £ (but since this
    # is the ISO-8859-1 version, it's not valid UTF-8).
    url_encoded = "%A3"
    base64ed = "ow=="
    raw = Base64.decode64(base64ed).force_encoding("utf-8")
    raw_utf8 = Base64.decode64(base64ed).encode("utf-8", :invalid => :replace, :undef => :replace)
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{raw}/#{raw_utf8}/?url_encoded=#{url_encoded}&base64ed=#{base64ed}&raw=#{raw}&raw_utf8=#{raw_utf8}", log_http_options.deep_merge({
      :headers => {
        "Content-Type" => url_encoded,
        "Referer" => base64ed,
        "Origin" => raw,
        "Accept" => raw_utf8,
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]

    # Since the encoding of this string wasn't actually a valid UTF-8 string,
    # we test situations where it's sent as the raw ISO-8859-1 value, as well
    # as the UTF-8 replacement character.
    expected_raw_in_url = url_encoded
    expected_raw_utf8_in_url = "%EF%BF%BD"

    # URL query string
    assert_equal(url_encoded, record["request_query"]["url_encoded"])
    assert_equal(base64ed, record["request_query"]["base64ed"])
    assert_equal(expected_raw_in_url, record["request_query"]["raw"])
    assert_equal(expected_raw_utf8_in_url, record["request_query"]["raw_utf8"])
  end

  def test_decodes_url_encoding
    url_encoded = "http%3A%2F%2Fexample.com%2Fsub%2Fsub%2F%3Ffoo%3Dbar%26foo%3Dbar%20more+stuff"
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{url_encoded}/?url_encoded=#{url_encoded}", log_http_options.deep_merge({
      :headers => {
        "Content-Type" => url_encoded,
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]

    # URL query string
    assert_equal(CGI.unescape(url_encoded), record["request_query"]["url_encoded"])
  end

  def test_optionally_encodable_ascii_strings
    as_is = "-%2D ;%3B +%2B /%2F :%3A 0%30 >%3E {%7B"
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{as_is}/?as_is=#{as_is}", log_http_options.deep_merge({
      :headers => {
        "Content-Type" => as_is,
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]

    # URL query string
    assert_equal(CGI.unescape(as_is), record["request_query"]["as_is"])
  end

  def test_slashes_and_backslashes
    url = "http://127.0.0.1:9080/api/hello/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash?&forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C"
    response = Typhoeus.get(url, log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("/slash", record["request_query"]["forward_slash"])
    assert_equal("/", record["request_query"]["encoded_forward_slash"])
    assert_equal("\\", record["request_query"]["back_slash"])
    assert_equal("\\", record["request_query"]["encoded_back_slash"])
    assert_equal("/api/hello/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash", record["request_path"])
    assert_equal(url, record["request_url"])
  end
end
