require_relative "../../test_helper"

class Test::Proxy::Routing::TestExplicitWebAppHost < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    @refute_fallback_website = true
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
          :backend_protocol => "http",
          :server_host => "127.0.0.1",
          :server_port => 9443,
        },
      ])

      override_config_set({
        "router" => {
          "web_app_host" => "127.0.0.1",
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  include ApiUmbrellaSharedTests::Routing
end
