require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestSetsHeaders < Minitest::Test
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
              { :key => "X-Add1", :value => "test1" },
              { :key => "X-Add2", :value => "test2" },
            ],
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/info/sub/",
              :settings => {
                :headers => [
                  { :key => "X-Add2", :value => "overridden" },
                ],
              },
            },
          ],
        },
      ])
    end
  end

  def test_sets_header_values
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "x-add1" => "test1",
      "x-add2" => "test2",
    }, strip_standard_request_headers(data["headers"]))
  end

  def test_overrides_and_merges_existing_headers_case_insensitively
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/", http_options.deep_merge({
      :headers => {
        "X-Add1" => "original1",
        "X-ADD2" => "original2",
        "X-Foo" => "bar",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "x-add1" => "test1",
      "x-add2" => "test2",
      "x-foo" => "bar",
    }, strip_standard_request_headers(data["headers"]))
  end

  def test_sub_url_settings_overrides_parent_settings
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/sub/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "x-add2" => "overridden",
    }, strip_standard_request_headers(data["headers"]))
  end
end
