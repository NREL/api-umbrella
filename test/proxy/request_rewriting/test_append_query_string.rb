require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestAppendQueryString < Minitest::Test
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
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/empty-append/", :backend_prefix => "/" }],
          :settings => {
            :append_query_string => "",
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/", :backend_prefix => "/" }],
          :settings => {
            :append_query_string => "add_param1=test1&add_param2=test2",
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/info/sub/",
              :settings => {
                :append_query_string => "add_param2=overridden&add_param3=new",
              },
            },
          ],
        },
      ])
    end
  end

  def test_appends_to_no_query_string
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "add_param1" => "test1",
      "add_param2" => "test2",
    }, data["url"]["query"])
  end

  def test_appends_to_empty_query_string
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/?", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "add_param1" => "test1",
      "add_param2" => "test2",
    }, data["url"]["query"])
  end

  def test_appends_to_existing_query_string
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/?test=value", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "test" => "value",
      "add_param1" => "test1",
      "add_param2" => "test2",
    }, data["url"]["query"])
  end

  def test_overrides_existing_query_string
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/?test=value&add_param1=original", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "test" => "value",
      "add_param1" => "test1",
      "add_param2" => "test2",
    }, data["url"]["query"])
  end

  def test_leaves_query_string_when_append_value_is_empty_string
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/empty-append/info/?test=value", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "test" => "value",
    }, data["url"]["query"])
  end

  def test_sub_url_settings_overrides_parent_settings
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/sub/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "add_param2" => "overridden",
      "add_param3" => "new",
    }, data["url"]["query"])
  end

  def test_preserves_query_string_order
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/?ccc=foo&aaa=bar&b=test", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("http://127.0.0.1/info/?ccc=foo&aaa=bar&b=test&add_param1=test1&add_param2=test2", data["raw_url"])
  end
end
