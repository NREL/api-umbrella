require_relative "../../test_helper"

class Test::Proxy::FormattedErrors::TestInvalidData < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::FormattedErrors

  parallelize_me!

  def setup
    super
    setup_server
    @api = {
      :name => unique_test_id,
      :frontend_host => "127.0.0.1",
      :backend_host => "127.0.0.1",
      :servers => [{ :host => "127.0.0.1", :port => 9444 }],
      :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      :settings => { :error_data => {} },
    }
  end

  def test_ignores_unexpected_string_value
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response, "API_KEY_MISSING")

      force_set_error_data("api_key_missing", "Foo")

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response, "API_KEY_MISSING")
    end
  end

  def test_ignores_unexpected_number_value
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response, "API_KEY_MISSING")

      force_set_error_data("api_key_missing", 9)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response, "API_KEY_MISSING")
    end
  end

  def test_ignores_unexpected_array_value
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response, "API_KEY_MISSING")

      force_set_error_data("api_key_missing", ["foo"])

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response, "API_KEY_MISSING")
    end
  end

  def test_ignores_unexpected_null_value
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response, "API_KEY_MISSING")

      force_set_error_data("api_key_missing", nil)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response, "API_KEY_MISSING")
    end
  end

  private

  def force_set_error_data(key, value)
    force_publish_config do |config|
      api_config = config.fetch("apis").find { |a| a["name"] == unique_test_id }
      api_config.fetch("settings").fetch("error_data")[key] = value
      config
    end
  end
end
