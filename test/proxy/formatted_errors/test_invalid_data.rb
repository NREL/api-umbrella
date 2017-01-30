require_relative "../../test_helper"

class Test::Proxy::FormattedErrors::TestInvalidData < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::FormattedErrors
  parallelize_me!

  def setup
    super
    setup_server
    @api = {
      :frontend_host => "127.0.0.1",
      :backend_host => "127.0.0.1",
      :servers => [{ :host => "127.0.0.1", :port => 9444 }],
      :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      :settings => { :error_data => {} },
    }
  end

  def test_unexpected_string_value_returns_internal_error
    @api[:settings][:error_data][:api_key_missing] = "Foo"
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_internal_server_error(response)
    end
  end

  def test_unexpected_number_value_returns_internal_error
    @api[:settings][:error_data][:api_key_missing] = 9
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_internal_server_error(response)
    end
  end

  def test_unexpected_array_value_returns_internal_error
    @api[:settings][:error_data][:api_key_missing] = ["foo"]
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_internal_server_error(response)
    end
  end

  def test_unexpected_null_value_returns_default_error
    @api[:settings][:error_data][:api_key_missing] = nil
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response)
    end
  end

  private

  def assert_json_internal_server_error(response)
    assert_response_code(500, response)
    assert_equal("application/json", response.headers["content-type"])
    data = MultiJson.load(response.body)
    assert_equal("INTERNAL_SERVER_ERROR", data["error"]["code"])
  end
end
