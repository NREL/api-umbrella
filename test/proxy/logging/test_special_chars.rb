require_relative "../../test_helper"

class Test::Proxy::Logging::TestSpecialChars < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    super
    setup_server
  end

  # To account for JSON escaping in nginx logs.
  def test_logs_headers_with_quotes
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "Referer" => "http://example.com/\"foo'bar",
        "Content-Type" => "text\"\x22plain'\\x22",
      },
      :userpwd => "\"foo'bar:bar\"foo'",
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("http://example.com/\"foo'bar", record["request_referer"])
    assert_equal("text\"\"plain'\\x22", record["request_content_type"])
    assert_equal("\"foo'bar", record["request_basic_auth_username"])
  end

  def test_logs_headers_with_special_chars
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "Referer" => "http://example.com/!\\*^%#[]",
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("http://example.com/!\\*^%#[]", record["request_referer"])
  end

  def test_logs_utf8_urls
    url = "http://127.0.0.1:9080/api/hello/utf8/✓/encoded_utf8/%E2%9C%93/?utf8=✓&utf8_url_encoded=%E2%9C%93&more_utf8=¬¶ªþ¤l&more_utf8_hex=\xC2\xAC\xC2\xB6\xC2\xAA\xC3\xBE\xC2\xA4l&more_utf8_hex_lowercase=\xc2\xac\xc2\xb6\xc2\xaa\xc3\xbe\xc2\xa4l&actual_backslash_x=\\xC2\\xAC\\xC2\\xB6\\xC2\\xAA\\xC3\\xBE\\xC2\\xA4l"
    response = Typhoeus.get(url, log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("/api/hello/utf8/%e2%9c%93/encoded_utf8/%E2%9C%93/", record["request_path"])
    assert_equal("utf8=%E2%9C%93&utf8_url_encoded=%E2%9C%93&more_utf8=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&more_utf8_hex=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&more_utf8_hex_lowercase=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&actual_backslash_x=\\xC2\\xAC\\xC2\\xB6\\xC2\\xAA\\xC3\\xBE\\xC2\\xA4l", record["request_url_query"])
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
    expected_raw_in_url_path = url_encoded.downcase
    expected_raw_in_url_query = url_encoded

    # URL
    assert_equal("/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url_path}/", record["request_path"])
    if $config["opensearch"]["template_version"] < 2
      assert_equal([
        "0/127.0.0.1:9080/",
        "1/127.0.0.1:9080/api/",
        "2/127.0.0.1:9080/api/hello/",
        "3/127.0.0.1:9080/api/hello/#{url_encoded}/",
        "4/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/",
        "5/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url_path}",
      ], record["request_hierarchy"])
      refute(record.key?("request_url_hierarchy_level0"))
      refute(record.key?("request_url_hierarchy_level1"))
      refute(record.key?("request_url_hierarchy_level2"))
      refute(record.key?("request_url_hierarchy_level3"))
      refute(record.key?("request_url_hierarchy_level4"))
      refute(record.key?("request_url_hierarchy_level5"))
      refute(record.key?("request_url_hierarchy_level6"))
    else
      assert_equal("127.0.0.1:9080/", record.fetch("request_url_hierarchy_level0"))
      assert_equal("api/", record.fetch("request_url_hierarchy_level1"))
      assert_equal("hello/", record.fetch("request_url_hierarchy_level2"))
      assert_equal("#{url_encoded}/", record.fetch("request_url_hierarchy_level3"))
      assert_equal("#{base64ed}/", record.fetch("request_url_hierarchy_level4"))
      assert_equal(expected_raw_in_url_path, record.fetch("request_url_hierarchy_level5"))
      refute(record.key?("request_url_hierarchy_level6"))
      refute(record.key?("request_hierarchy"))
    end
    assert_equal("url_encoded=#{url_encoded}&base64ed=#{base64ed}&raw=#{expected_raw_in_url_query}", record["request_url_query"])

    # HTTP headers
    assert_equal(url_encoded, record["request_content_type"])
    assert_equal(base64ed, record["request_referer"])
    assert_equal(raw, record["request_origin"])
  end

  def test_invalid_utf8_encoding_in_url_path_url_params_headers
    log_tail = LogTail.new("fluent-bit/current")

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

    log = log_tail.read.encode("UTF-8", invalid: :replace)
    # Fluent Bit's UTF-8 handling appears to be different on x86_64 versus
    # ARM64. I believe related to this open issue:
    # https://github.com/fluent/fluent-bit/issues/7995
    #
    # So on ARM64, it complains about UTF-8, which I think is more expected
    # since we are sending in invalid encoded data. But on x86-64 systems, this
    # doesn't appear to happen. I think we're okay with either behavior,
    # really, we mainly just want to make sure things don't crash when
    # encountering this type of weird input.
    if RUBY_PLATFORM.start_with?("x86_64")
      refute_match("invalid UTF-8 bytes found, skipping bytes", log)
    else
      assert_match("invalid UTF-8 bytes found, skipping bytes", log)
    end

    # Since the encoding of this string wasn't actually a valid UTF-8 string,
    # we test situations where it's sent as the raw ISO-8859-1 value, as well
    # as the UTF-8 replacement character.
    expected_raw_in_url_path = url_encoded.downcase
    expected_raw_in_url_query = url_encoded
    # See above for differences in platform.
    if RUBY_PLATFORM.start_with?("x86_64")
      expected_raw_in_header = "\uE0A3"
    else
      expected_raw_in_header = ""
    end
    expected_raw_utf8_in_url_path = "%ef%bf%bd"
    expected_raw_utf8_in_url_query = "%EF%BF%BD"
    expected_raw_utf8_in_header = Base64.decode64("77+9").force_encoding("utf-8")

    # URL
    assert_equal("/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url_path}/#{expected_raw_utf8_in_url_path}/", record["request_path"])
    if $config["opensearch"]["template_version"] < 2
      assert_equal([
        "0/127.0.0.1:9080/",
        "1/127.0.0.1:9080/api/",
        "2/127.0.0.1:9080/api/hello/",
        "3/127.0.0.1:9080/api/hello/#{url_encoded}/",
        "4/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/",
        "5/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url_path}/",
        "6/127.0.0.1:9080/api/hello/#{url_encoded}/#{base64ed}/#{expected_raw_in_url_path}/#{expected_raw_utf8_in_url_path}",
      ], record["request_hierarchy"])
      refute(record.key?("request_url_hierarchy_level0"))
      refute(record.key?("request_url_hierarchy_level1"))
      refute(record.key?("request_url_hierarchy_level2"))
      refute(record.key?("request_url_hierarchy_level3"))
      refute(record.key?("request_url_hierarchy_level4"))
      refute(record.key?("request_url_hierarchy_level5"))
      refute(record.key?("request_url_hierarchy_level6"))
    else
      assert_equal("127.0.0.1:9080/", record.fetch("request_url_hierarchy_level0"))
      assert_equal("api/", record.fetch("request_url_hierarchy_level1"))
      assert_equal("hello/", record.fetch("request_url_hierarchy_level2"))
      assert_equal("#{url_encoded}/", record.fetch("request_url_hierarchy_level3"))
      assert_equal("#{base64ed}/", record.fetch("request_url_hierarchy_level4"))
      assert_equal("#{expected_raw_in_url_path}/", record.fetch("request_url_hierarchy_level5"))
      assert_equal(expected_raw_utf8_in_url_path, record.fetch("request_url_hierarchy_level6"))
      refute(record.key?("request_hierarchy"))
    end
    assert_equal("url_encoded=#{url_encoded}&base64ed=#{base64ed}&raw=#{expected_raw_in_url_query}&raw_utf8=#{expected_raw_utf8_in_url_query}", record["request_url_query"])

    # HTTP headers
    assert_equal(url_encoded, record["request_content_type"])
    assert_equal(base64ed, record["request_referer"])
    assert_equal(expected_raw_in_header, record["request_origin"])
    assert_equal(expected_raw_utf8_in_header, record["request_accept"])
  end

  def test_encoded_strings_as_given
    url_encoded = "http%3A%2F%2Fexample.com%2Fsub%2Fsub%2F%3Ffoo%3Dbar%26foo%3Dbar%20more+stuff"
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{url_encoded}/?url_encoded=#{url_encoded}", log_http_options.deep_merge({
      :headers => {
        "Content-Type" => url_encoded,
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]

    # URL
    assert_equal("/api/hello/#{url_encoded}/", record["request_path"])
    if $config["opensearch"]["template_version"] < 2
      assert_equal([
        "0/127.0.0.1:9080/",
        "1/127.0.0.1:9080/api/",
        "2/127.0.0.1:9080/api/hello/",
        "3/127.0.0.1:9080/api/hello/#{url_encoded}",
      ], record["request_hierarchy"])
      refute(record.key?("request_url_hierarchy_level0"))
      refute(record.key?("request_url_hierarchy_level1"))
      refute(record.key?("request_url_hierarchy_level2"))
      refute(record.key?("request_url_hierarchy_level3"))
      refute(record.key?("request_url_hierarchy_level4"))
      refute(record.key?("request_url_hierarchy_level5"))
      refute(record.key?("request_url_hierarchy_level6"))
    else
      assert_equal("127.0.0.1:9080/", record.fetch("request_url_hierarchy_level0"))
      assert_equal("api/", record.fetch("request_url_hierarchy_level1"))
      assert_equal("hello/", record.fetch("request_url_hierarchy_level2"))
      assert_equal(url_encoded, record.fetch("request_url_hierarchy_level3"))
      refute(record.key?("request_url_hierarchy_level4"))
      refute(record.key?("request_url_hierarchy_level5"))
      refute(record.key?("request_url_hierarchy_level6"))
      refute(record.key?("request_hierarchy"))
    end
    assert_equal("url_encoded=#{url_encoded}", record["request_url_query"])

    # HTTP headers
    assert_equal(url_encoded, record["request_content_type"])
  end

  def test_optionally_encodable_ascii_strings_as_given
    as_is = "-%2D%20;%3B%20+%2B%20/%2F%20:%3A%200%30%20>%3E%20{%7B"
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello/#{as_is}/?as_is=#{as_is}", log_http_options.deep_merge({
      :headers => {
        "Content-Type" => as_is,
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]

    # URL
    assert_equal("/api/hello/#{as_is}/", record["request_path"])
    if $config["opensearch"]["template_version"] < 2
      assert_equal([
        "0/127.0.0.1:9080/",
        "1/127.0.0.1:9080/api/",
        "2/127.0.0.1:9080/api/hello/",
        "3/127.0.0.1:9080/api/hello/-%2D ;%3B +%2B /",
        "4/127.0.0.1:9080/api/hello/-%2D ;%3B +%2B /%2F :%3A 0%30 >%3E {%7B",
      ], record["request_hierarchy"])
      refute(record.key?("request_url_hierarchy_level0"))
      refute(record.key?("request_url_hierarchy_level1"))
      refute(record.key?("request_url_hierarchy_level2"))
      refute(record.key?("request_url_hierarchy_level3"))
      refute(record.key?("request_url_hierarchy_level4"))
      refute(record.key?("request_url_hierarchy_level5"))
      refute(record.key?("request_url_hierarchy_level6"))
    else
      assert_equal("127.0.0.1:9080/", record.fetch("request_url_hierarchy_level0"))
      assert_equal("api/", record.fetch("request_url_hierarchy_level1"))
      assert_equal("hello/", record.fetch("request_url_hierarchy_level2"))
      assert_equal("-%2D%20;%3B%20+%2B%20/", record.fetch("request_url_hierarchy_level3"))
      assert_equal("%2F%20:%3A%200%30%20>%3E%20{%7B", record.fetch("request_url_hierarchy_level4"))
      refute(record.key?("request_url_hierarchy_level5"))
      refute(record.key?("request_url_hierarchy_level6"))
      refute(record.key?("request_hierarchy"))
    end

    assert_equal("as_is=#{as_is}", record["request_url_query"])

    # HTTP headers
    assert_equal(as_is, record["request_content_type"])
  end

  def test_slashes_and_backslashes
    url = "http://127.0.0.1:9080/api/hello/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash?&forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C"
    response = Typhoeus.get(url, log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("/api/hello/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash", record["request_path"])
    assert_equal("&forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C", record["request_url_query"])
  end

  def test_invalid_quotes
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", log_http_options.deep_merge({
      :headers => {
        "User-Agent" => Base64.decode64("eyJ1c2VyX2FnZW50IjogImZvbyDAp8CiIGJhciJ9"),
        "Referer" => Base64.decode64("eyJ1c2VyX2FnZW50IjogImZvbyDAp8CiIGJhciJ9"),
      },
    }))
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]
    assert_equal("{\"user_agent\": \"foo ?? bar\"}", record["request_referer"])
    assert_equal("{\"user_agent\": \"foo ?? bar\"}", record["request_user_agent"])
  end
end
