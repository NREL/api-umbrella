require_relative "../../test_helper"

class Test::Proxy::FormattedErrors::TestInvalidTemplates < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/", :backend_prefix => "/" }],
          :settings => {
            :error_data => {
              :api_key_missing => {
                :newvar => "foo",
                :message => "new message",
              },
            },
            :error_templates => {
              :json => '{ "unknown": {{bogusvar}} }',
              :xml => "<invalid>{{oops}</invalid>",
            },
          },
        },
      ])
    end
  end

  def test_undefined_variables_remains
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/hello.json", keyless_http_options)
    assert_response_code(403, response)
    assert_equal("application/json", response.headers["content-type"])
    assert_equal('{ "unknown": {{bogusvar}} }', response.body)
  end

  def test_template_syntax_error_remains
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/hello.xml", keyless_http_options)
    assert_response_code(403, response)
    assert_equal("application/xml", response.headers["content-type"])
    assert_equal("<invalid>{{oops}</invalid>", response.body)
  end
end
