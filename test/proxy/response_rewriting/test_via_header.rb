require_relative "../../test_helper"

class Test::Proxy::ResponseRewriting::TestViaHeader < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_returns_trafficserver_via_details_but_omits_version_and_host
    response = Typhoeus.get("http://127.0.0.1:9080/api/hello?cache-busting=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    assert_equal("http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])", response.headers["via"])
  end

  def test_appends_trafficserver_via_to_backend_via
    response = Typhoeus.get("http://127.0.0.1:9080/api/via-header/?cache-busting=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    assert_equal("1.0 fred, 1.1 nowhere.com (Apache/1.1), http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])", response.headers["via"])
  end
end
