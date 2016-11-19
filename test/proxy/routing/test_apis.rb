require_relative "../../test_helper"

class TestProxyRoutingApis < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_gives_precedence_to_internal_apis
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/api-umbrella/", :backend_prefix => "/info/" }],
      },
    ]) do
      response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/state.json", self.http_options.except(:headers))
      assert_equal(200, response.code, response.body)
      data = MultiJson.load(response.body)
      assert(data["db_config_version"])
    end
  end
end
