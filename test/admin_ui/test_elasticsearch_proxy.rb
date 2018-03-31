require_relative "../test_helper"

# Deprecated: Remove this test, since we're no longer providing this proxy
# functionality.
class Test::AdminUi::TestElasticsearchProxy < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_not_found_for_unauthenticated_requests
    FactoryBot.create(:admin)

    visit "/admin/elasticsearch"
    assert_equal(404, page.status_code)

    visit "/admin/elasticsearch/_search"
    assert_equal(404, page.status_code)
  end

  def test_not_found_for_unauthorized_admins
    admin_login(FactoryBot.create(:limited_admin))

    visit "/admin/elasticsearch"
    assert_equal(404, page.status_code)

    visit "/admin/elasticsearch/_search"
    assert_equal(404, page.status_code)
  end

  def test_not_found_for_superuser_admins
    admin_login

    visit "/admin/elasticsearch"
    assert_equal(404, page.status_code)

    visit "/admin/elasticsearch/_search"
    assert_equal(404, page.status_code)

    # Redirect rewriting
    response = Typhoeus.get("https://127.0.0.1:9081/admin/elasticsearch/_plugin/foobar", keyless_http_options.deep_merge({
      :headers => {
        "Cookie" => "_api_umbrella_session=#{page.driver.cookies["_api_umbrella_session"].value}",
      },
    }))
    assert_response_code(404, response)
  end
end
