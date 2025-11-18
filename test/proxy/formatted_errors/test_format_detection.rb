require_relative "../../test_helper"

class Test::Proxy::FormattedErrors::TestFormatDetection < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::FormattedErrors

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_first_priority_path_extension
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello.xml?format=json", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "application/json",
      },
    }))
    assert_xml_error(response)
  end

  def test_second_priority_query_param
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?format=xml", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "application/json",
      },
    }))
    assert_xml_error(response)
  end

  def test_third_priority_content_negotiation
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "application/json;q=0.5,application/xml;q=0.9",
      },
    }))
    assert_xml_error(response)
  end

  def test_defaults_to_json_when_no_format_detected
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options)
    assert_json_error(response)
  end

  def test_defaults_to_json_when_unsupported_format_detected
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello.mov", keyless_http_options)
    assert_json_error(response)
  end

  def test_defaults_to_json_when_unknown_format_detected
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello.zzz", keyless_http_options)
    assert_json_error(response)
  end

  def test_uses_path_extension_despite_invalid_query_params
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello.xml?format=json&test=test&url=%ED%A1%BC", keyless_http_options)
    assert_xml_error(response)
  end

  def test_gracefully_handles_array_format_query_param
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?format[]=xml", keyless_http_options)
    assert_json_error(response)
  end

  def test_gracefully_handles_duplicate_format_query_param
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?format=xml&format=csv", keyless_http_options)
    assert_xml_error(response)
  end

  def test_gracefully_handles_hash_format_query_param
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?format[key]=xml", keyless_http_options)
    assert_json_error(response)
  end

  def test_gracefully_handles_empty_array_format_query_param
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?format[]=", keyless_http_options)
    assert_json_error(response)
  end
end
