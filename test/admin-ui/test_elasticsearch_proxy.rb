require_relative "../test_helper"

class TestAdminUiElasticsearchProxy < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTests::AdminAuth
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
  end

  def test_redirect_to_login_for_unauthenticated_requests
    visit "/admin/elasticsearch"
    assert_content("You need to sign in")
    refute_content('"lucene_version"')
    assert_match(%r{/admin/login\z}, page.current_url)

    visit "/admin/elasticsearch/_search"
    assert_content("You need to sign in")
    refute_content('"hits"')
    assert_match(%r{/admin/login\z}, page.current_url)
  end

  def test_forbidden_for_unauthorized_admins
    admin_login(FactoryGirl.create(:limited_admin))

    visit "/admin/elasticsearch"
    assert_equal(403, page.status_code)
    assert_content("Forbidden")
    refute_content('"lucene_version"')

    visit "/admin/elasticsearch/_search"
    assert_equal(403, page.status_code)
    assert_content("Forbidden")
    refute_content('"hits"')
  end

  def test_allowed_for_superuser_admins
    admin_login

    visit "/admin/elasticsearch"
    assert_equal(200, page.status_code)
    assert_content('"lucene_version"')

    visit "/admin/elasticsearch/_search"
    assert_equal(200, page.status_code)
    assert_content('"hits"')

    # Redirect rewriting
    response = Typhoeus.get("https://127.0.0.1:9081/admin/elasticsearch/_plugin/foobar", {
      :ssl_verifypeer => false,
      :headers => {
        "Cookie" => "_api_umbrella_session=#{page.driver.cookies["_api_umbrella_session"].value}",
      },
    })
    assert_equal(301, response.code, response.body)
    assert_equal("/admin/elasticsearch/_plugin/foobar/", response.headers["Location"])
    assert_match(%r{URL=/admin/elasticsearch/_plugin/foobar/>}, response.body)
    assert_equal(response.body.bytesize, response.headers["Content-Length"].to_i)
  end
end
