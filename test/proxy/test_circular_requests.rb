require_relative "../test_helper"

class Test::Proxy::TestCircularRequests < Minitest::Test
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
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/circular-backend/", :backend_prefix => "/info/circular-example/" }],
          :settings => {
            :disable_api_key => true,
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9080 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/circular-frontend/", :backend_prefix => "/#{unique_test_class_id}/circular-backend/" }],
        },
      ])
    end
  end

  def test_allows_backend_config_to_reference_same_api_umbrella_instance
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/circular-frontend/?cache-busting=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    assert_equal("http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ]), http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])", response.headers["via"])
    data = MultiJson.load(response.body)
    assert_equal("/info/circular-example/?cache-busting=#{unique_test_id}", data["url"]["path"])
  end
end
