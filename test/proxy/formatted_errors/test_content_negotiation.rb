require_relative "../../test_helper"

class Test::Proxy::FormattedErrors::TestContentNegotiation < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::FormattedErrors

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_application_json
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "application/json",
      },
    }))
    assert_json_error(response)
  end

  def test_application_xml
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "application/xml",
      },
    }))
    assert_xml_error(response, "application/xml")
  end

  def test_text_xml
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "text/xml",
      },
    }))
    assert_xml_error(response, "text/xml")
  end

  def test_text_csv
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "text/csv",
      },
    }))
    assert_csv_error(response)
  end

  def test_text_html
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "text/html",
      },
    }))
    assert_html_error(response)
  end

  def test_highest_quality_factor
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "application/json;q=0.5, application/xml;q=0.4, */*;q=0.1, text/csv;q=0.8",
      },
    }))
    assert_csv_error(response)
  end

  def test_first_supported_wildcard_type
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "application/*;q=0.5, text/*;q=0.6",
      },
    }))
    assert_xml_error(response, "text/xml")
  end

  def test_picks_first_when_no_other_precedence
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "text/csv, application/json;q=0.5, application/xml, */*;q=0.1",
      },
    }))
    assert_csv_error(response)
  end

  def test_defaults_to_json_for_unknown_type
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "text/foo",
      },
    }))
    assert_json_error(response)
  end

  def test_defaults_to_json_for_wildcard_type
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", keyless_http_options.deep_merge({
      :headers => {
        "Accept" => "*/*",
      },
    }))
    assert_json_error(response)
  end
end
