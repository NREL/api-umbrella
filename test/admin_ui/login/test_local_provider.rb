require_relative "../../test_helper"

class Test::AdminUi::Login::TestLocalProvider < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::DelayServerResponses
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    Admin.delete_all
    @admin = FactoryGirl.create(:admin)
  end

  def test_allows_first_time_admin_creation
    Admin.delete_all
    assert_equal(0, Admin.count)
    assert_first_time_admin_creation_allowed
  end

  def test_shows_local_login_fields_no_external_login_links
    visit "/admin/login"

    assert_content("Admin Sign In")

    # Local login fields
    assert_field("Email")
    assert_field("Password")
    assert_field("Remember me")
    assert_link("Forgot your password?")
    assert_button("Sign in")

    # No external login links
    refute_content("Sign in with")
  end

  def test_login_redirects
    # Slow down the server side responses to validate the "Loading..." spinner
    # shows up (without slowing things down, it periodically goes away too
    # quickly for the tests to catch).
    delay_server_responses(0.5) do
      visit "/admin/"

      # Ensure we get the loading spinner until authentication takes place.
      assert_content("Loading...")

      # Navigation should not be visible while loading.
      refute_selector("nav")
      refute_content("Analytics")

      # Ensure that we eventually get redirected to the login page.
      assert_content("Admin Sign In")
    end
  end

  # Since we do some custom things related to the Rails asset path, make sure
  # everything is hooked up and the production cache-bused assets are served
  # up.
  def test_login_assets
    visit "/admin/login"
    assert_content("Admin Sign In")

    # Find the stylesheet on the Rails login page, which should have a
    # cache-busted URL (note that the href on the page appears to be relative,
    # but capybara seems to read it as absolute. That's fine, but noting it in
    # case Capybara's future behavior changes).
    stylesheet = find("link[rel=stylesheet]", :visible => :hidden)
    assert_match(%r{\Ahttps://127\.0\.0\.1:9081/web-assets/admin/login-\w{64}\.css\z}, stylesheet[:href])

    # Verify that the asset URL can be fetched and returns data.
    response = Typhoeus.get(stylesheet[:href], keyless_http_options)
    assert_response_code(200, response)
    assert_equal("text/css", response.headers["content-type"])
  end
end
