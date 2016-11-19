require_relative "../../test_helper"

class TestProxyRoutingDefaultWildcardWebAppHost < Minitest::Test
  include ApiUmbrellaTests::Setup
  parallelize_me!

  def setup
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "#{unique_test_class_id}-apis-no-website.foo",
          :backend_host => "apis-no-website.bar",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}-api/", :backend_prefix => "/" }],
        },
      ])

      prepend_website_backends([
        {
          :frontend_host => "#{unique_test_class_id}-website.foo",
          :server_host => "127.0.0.1",
          :server_port => 9443,
        },
      ])
    end
  end

  include ApiUmbrellaTests::Routing
end
