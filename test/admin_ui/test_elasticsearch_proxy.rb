require_relative "../test_helper"

class Test::AdminUi::TestElasticsearchProxy < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_no_longer_exists_for_unauthenticated_requests
    FactoryBot.create(:admin)

    response = Typhoeus.get("https://127.0.0.1:9081/admin/elasticsearch", keyless_http_options)
    assert_response_code(404, response)

    response = Typhoeus.get("https://127.0.0.1:9081/admin/elasticsearch/_search", keyless_http_options)
    assert_response_code(404, response)
  end

  def test_no_longer_exists_for_unauthorized_admins
    admin = FactoryBot.create(:limited_admin)

    response = Typhoeus.get("https://127.0.0.1:9081/admin/elasticsearch", keyless_http_options.deep_merge(admin_session(admin)))
    assert_response_code(404, response)

    response = Typhoeus.get("https://127.0.0.1:9081/admin/elasticsearch/_search", keyless_http_options.deep_merge(admin_session(admin)))
    assert_response_code(404, response)
  end

  def test_no_longer_exists_for_superuser_admins
    admin = FactoryBot.create(:admin)

    response = Typhoeus.get("https://127.0.0.1:9081/admin/elasticsearch", keyless_http_options.deep_merge(admin_session(admin)))
    assert_response_code(404, response)

    response = Typhoeus.get("https://127.0.0.1:9081/admin/elasticsearch/_search", keyless_http_options.deep_merge(admin_session(admin)))
    assert_response_code(404, response)
  end
end
