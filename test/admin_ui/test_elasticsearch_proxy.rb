require_relative "../test_helper"

class Test::AdminUi::TestElasticsearchProxy < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_redirect_to_login_for_unauthenticated_requests
    FactoryBot.create(:admin)

    visit "/admin/elasticsearch"
    assert_text("You need to sign in")
    refute_text('"lucene_version"')
    assert_match(%r{/admin/login\z}, page.current_url)

    visit "/admin/elasticsearch/_search"
    assert_text("You need to sign in")
    refute_text('"hits"')
    assert_match(%r{/admin/login\z}, page.current_url)
  end

  def test_forbidden_for_unauthorized_admins
    admin_login(FactoryBot.create(:limited_admin))

    visit "/admin/elasticsearch"
    assert_equal(403, page.status_code)
    assert_text("Forbidden")
    refute_text('"lucene_version"')

    visit "/admin/elasticsearch/_search"
    assert_equal(403, page.status_code)
    assert_text("Forbidden")
    refute_text('"hits"')
  end

  def test_allowed_for_superuser_admins
    admin_login

    visit "/admin/elasticsearch"
    assert_equal(200, page.status_code)
    assert_text('"lucene_version"')

    visit "/admin/elasticsearch/_search"
    assert_equal(200, page.status_code)
    assert_text('"hits"')

    # Redirect rewriting
    response = Typhoeus.get("https://127.0.0.1:9081/admin/elasticsearch/_plugin/foobar", keyless_http_options.deep_merge({
      :headers => {
        "Cookie" => "_api_umbrella_session=#{page.driver.cookies["_api_umbrella_session"].value}",
      },
    }))
    assert_response_code(301, response)
    assert_equal("/admin/elasticsearch/_plugin/foobar/", response.headers["Location"])
    assert_match(%r{URL=/admin/elasticsearch/_plugin/foobar/}, response.body)
    assert_equal(response.body.bytesize, response.headers["Content-Length"].to_i)
  end
end
