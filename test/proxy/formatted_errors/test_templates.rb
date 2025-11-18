require_relative "../../test_helper"

class Test::Proxy::FormattedErrors::TestTemplates < Minitest::Test
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
      :settings => { :error_data => {}, :error_templates => {} },
    }
  end

  def test_strips_leading_and_trailing_whitespace
    @api[:settings][:error_templates].deep_merge!({
      :json => %( \n\n  { "code": {{code}} } \n\n  ),
      :xml => %( \n\n  <?xml version="1.0" encoding="UTF-8"?><code>{{code}}</code> \n\n  ),
      :csv => %( \n\n  Code\n{{code}} \n\n  ),
      :html => %( \n\n  <html><body><h1>{{code}}</h1></body></html> \n\n  ),
    })
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_equal('{ "code": "API_KEY_MISSING" }', response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.xml", keyless_http_options)
      assert_equal('<?xml version="1.0" encoding="UTF-8"?><code>API_KEY_MISSING</code>', response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.csv", keyless_http_options)
      assert_equal(%(Code\n"API_KEY_MISSING"), response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.html", keyless_http_options)
      assert_equal("<html><body><h1>API_KEY_MISSING</h1></body></html>", response.body)
    end
  end

  def test_uses_default_if_api_specific_settings_are_empty_objects
    @api[:settings][:error_data] = {}
    @api[:settings][:error_templates] = {}
    prepend_api_backends([@api]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/hello.json", keyless_http_options)
      assert_json_error(response)
      data = MultiJson.load(response.body)
      assert_equal(["error"].sort, data.keys.sort)
      assert_equal(["code", "message"].sort, data["error"].keys.sort)
    end
  end
end
