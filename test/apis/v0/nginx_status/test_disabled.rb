require_relative "../../../test_helper"

class Test::Apis::V0::NginxStatus::TestDisabled < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_disabled_by_default
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v0/nginx-status", http_options)
    assert_response_code(404, response)
  end
end
