require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestApiPathPrefix < Minitest::Test
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
          :url_matches => [{
            :frontend_prefix => "/#{unique_test_class_id}/incoming/",
            :backend_prefix => "/info/outgoing/",
          }],
        },
      ])
    end
  end

  def test_rewrites_prefix
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/incoming/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/outgoing/", data["url"]["path"])
  end

  def test_retains_path_beyond_prefix
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/incoming/foo/bar", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/outgoing/foo/bar", data["url"]["path"])
  end

  def test_retains_query_params
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/incoming/foo/bar?param1=value1&param2=value2", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/outgoing/foo/bar?param1=value1&param2=value2", data["url"]["path"])
  end
end
