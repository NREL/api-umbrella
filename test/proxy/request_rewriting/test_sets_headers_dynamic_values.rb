require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestSetsHeadersDynamicValues < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::StripStandardRequestHeaders

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
            :headers => [
              { :key => "X-Dynamic", :value => "({{headers.x-dynamic-source}}-{{headers.x-dynamic-source}})" },
              { :key => "X-Dynamic-Missing", :value => "{{headers.x-missing}}" },
              { :key => "X-Dynamic-Default-Absent", :value => "{{#headers.x-missing}}{{headers.x-missing}}{{/headers.x-missing}}{{^headers.x-missing}}default{{/headers.x-missing}}" },
              { :key => "X-Dynamic-Default-Present", :value => "{{#headers.x-dynamic-source}}{{headers.x-dynamic-source}}{{/headers.x-dynamic-source}}{{^headers.x-dynamic-source}}static{{/headers.x-dynamic-source}}" },
            ],
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/info/sub/",
              :settings => {
                :headers => [
                  { :key => "X-Dynamic-Sub", :value => "{{headers.x-dynamic-source}}" },
                ],
              },
            },
          ],
        },
      ])
    end
  end

  def test_if_statements
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/", http_options.deep_merge({
      :headers => {
        "X-Dynamic-Source" => "dynamic",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "x-dynamic" => "(dynamic-dynamic)",
      "x-dynamic-source" => "dynamic",
      # x-dynamic-missing is not set
      "x-dynamic-default-absent" => "default",
      "x-dynamic-default-present" => "dynamic",
    }, strip_standard_request_headers(data["headers"]))
  end

  def test_inverted_statements
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/", http_options.deep_merge({
      :headers => {
        "X-Missing" => "not-missing",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "x-dynamic" => "(-)",
      "x-missing" => "not-missing",
      "x-dynamic-missing" => "not-missing",
      "x-dynamic-default-absent" => "not-missing",
      "x-dynamic-default-present" => "static",
    }, strip_standard_request_headers(data["headers"]))
  end

  def test_sub_url_settings_overrides_parent_settings
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/sub/", http_options.deep_merge({
      :headers => {
        "X-Dynamic-Source" => "dynamic",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "x-dynamic-source" => "dynamic",
      "x-dynamic-sub" => "dynamic",
    }, strip_standard_request_headers(data["headers"]))
  end
end
