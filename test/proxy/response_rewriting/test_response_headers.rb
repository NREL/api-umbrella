require_relative "../../test_helper"

class Test::Proxy::ResponseRewriting::TestResponseHeaders < Minitest::Test
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
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/default/", :backend_prefix => "/" }],
          :settings => {
            :default_response_headers => [
              { :key => "X-Add1", :value => "test1" },
              { :key => "X-Add2", :value => "test2" },
              { :key => "X-Existing1", :value => "test3" },
              { :key => "X-EXISTING2", :value => "test4" },
              { :key => "x-existing3", :value => "test5" },
            ],
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/headers/sub/",
              :settings => {
                :default_response_headers => [
                  { :key => "X-Add2", :value => "overridden" },
                ],
              },
            },
          ],
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/override/", :backend_prefix => "/" }],
          :settings => {
            :override_response_headers => [
              { :key => "X-Add1", :value => "test1" },
              { :key => "X-Add2", :value => "test2" },
              { :key => "X-Existing1", :value => "test3" },
              { :key => "X-EXISTING2", :value => "test4" },
              { :key => "x-existing3", :value => "test5" },
            ],
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/headers/sub/",
              :settings => {
                :override_response_headers => [
                  { :key => "X-Existing3", :value => "overridden" },
                ],
              },
            },
          ],
        },
      ])
    end
  end

  def test_default_sets_new_headers
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/default/headers/", http_options)
    assert_response_code(200, response)
    assert_equal("test1", response.headers["x-add1"])
    assert_equal("test2", response.headers["x-add2"])
  end

  def test_default_leaves_existing_headers_case_insensitive
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/default/headers/", http_options)
    assert_response_code(200, response)
    assert_equal("existing1", response.headers["x-existing1"])
    assert_equal("existing2", response.headers["x-existing2"])
    assert_equal("existing3", response.headers["x-existing3"])
  end

  def test_default_sub_settings
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/default/headers/sub/", http_options)
    assert_response_code(200, response)
    refute(response.headers["x-add1"])
    assert_equal("overridden", response.headers["x-add2"])
    assert_equal("existing1", response.headers["x-existing1"])
    assert_equal("existing2", response.headers["x-existing2"])
    assert_equal("existing3", response.headers["x-existing3"])
  end

  def test_override_sets_new_headers
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/override/headers/", http_options)
    assert_response_code(200, response)
    assert_equal("test1", response.headers["x-add1"])
    assert_equal("test2", response.headers["x-add2"])
  end

  def test_override_replaces_existing_headers_case_insensitive
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/override/headers/", http_options)
    assert_response_code(200, response)
    assert_equal("test3", response.headers["x-existing1"])
    assert_equal("test4", response.headers["x-existing2"])
    assert_equal("test5", response.headers["x-existing3"])
  end

  def test_override_sub_settings
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/override/headers/sub/", http_options)
    assert_response_code(200, response)
    refute(response.headers["x-add1"])
    refute(response.headers["x-add2"])
    assert_equal("existing1", response.headers["x-existing1"])
    assert_equal("existing2", response.headers["x-existing2"])
    assert_equal("overridden", response.headers["x-existing3"])
  end
end
