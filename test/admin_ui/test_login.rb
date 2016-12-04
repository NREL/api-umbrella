require_relative "../test_helper"

class Test::AdminUi::TestLogin < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::DelayServerResponses
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    Admin.where(:registration_source.ne => "seed").delete_all
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
      assert_content("Admin Login")
      assert_content("Login with")
    end
  end

  # Since we do some custom things related to the Rails asset path, make sure
  # everything is hooked up and the production cache-bused assets are served
  # up.
  def test_login_assets
    visit "/admin/login"
    assert_content("Admin Login")

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

  def test_facebook
    assert_login(:facebook, "Login with Facebook", "info.email", "info.verified")
  end

  def test_github
    assert_login(:github, "Login with GitHub", "info.email", "info.email_verified")
  end

  def test_google_oauth2
    assert_login(:google_oauth2, "Login with Google", "info.email", "extra.raw_info.email_verified")
  end

  def test_ldap
    assert_login(:ldap, "Login with LDAP", "extra.raw_info.sAMAccountName")
  end

  def test_max_gov
    assert_login(:cas, "Login with MAX.gov", "uid")
  end

  def test_persona
    assert_login(:persona, "Login with Persona", "info.email")
  end

  private

  def assert_login(provider, login_button_text, username_path, verified_path = nil)
    omniauth_base_data = LazyHash.build_hash
    omniauth_base_data["provider"] = provider.to_s
    if(verified_path)
      LazyHash.add(omniauth_base_data, verified_path, true)
    end

    assert_login_valid_admin(omniauth_base_data, login_button_text, username_path)
    assert_login_case_insensitive_username_admin(omniauth_base_data, login_button_text, username_path)
    assert_login_nonexistent_admin(omniauth_base_data, login_button_text, username_path)
    if(verified_path)
      assert_login_unverified_email_login(omniauth_base_data, login_button_text, username_path, verified_path)
    end
  end

  def assert_login_valid_admin(omniauth_base_data, login_button_text, username_path)
    omniauth_data = omniauth_base_data.deep_dup
    admin = FactoryGirl.create(:admin, :username => "valid@example.com")
    LazyHash.add(omniauth_data, username_path, admin.username)

    mock_omniauth(omniauth_data) do
      assert_login_permitted(login_button_text, admin)
    end
  end

  def assert_login_case_insensitive_username_admin(omniauth_base_data, login_button_text, username_path)
    omniauth_data = omniauth_base_data.deep_dup
    admin = FactoryGirl.create(:admin, :username => "hello@example.com")
    LazyHash.add(omniauth_data, username_path, "Hello@ExamplE.Com")

    mock_omniauth(omniauth_data) do
      assert_login_permitted(login_button_text, admin)
    end
  end

  def assert_login_nonexistent_admin(omniauth_base_data, login_button_text, username_path)
    omniauth_data = omniauth_base_data.deep_dup
    LazyHash.add(omniauth_data, username_path, "noadmin@example.com")

    mock_omniauth(omniauth_data) do
      assert_login_forbidden(login_button_text)
    end
  end

  def assert_login_unverified_email_login(omniauth_base_data, login_button_text, username_path, verified_path)
    omniauth_data = omniauth_base_data.deep_dup
    admin = FactoryGirl.create(:admin, :username => "unverified@example.com")
    LazyHash.add(omniauth_data, username_path, admin.username)
    LazyHash.add(omniauth_data, verified_path, false)

    mock_omniauth(omniauth_data) do
      assert_login_forbidden(login_button_text)
    end
  end

  def assert_login_permitted(login_button_text, admin)
    visit "/admin/"
    click_server_side_link(login_button_text)
    assert_link("my_account_nav_link", :href => /#{admin.id}/, :visible => :all)
  end

  def assert_login_forbidden(login_button_text)
    visit "/admin/"
    click_server_side_link(login_button_text)
    assert_text("not authorized")
    refute_link("my_account_nav_link")
  end

  def mock_omniauth(omniauth_data)
    # Set a cookie to mock the OmniAuth responses. This relies on the
    # TestMockOmniauth middleware we install into the Rails app during the test
    # environment. This gives us a way to mock this data from outside the Rails
    # test suite.
    Capybara.reset_session!
    page.driver.set_cookie("test_mock_omniauth", Base64.urlsafe_encode64(MultiJson.dump(omniauth_data)))
    yield
  ensure
    page.driver.remove_cookie("test_mock_omniauth")
  end

  # When using "click_link" on the login buttons we rarely/sporadically see it
  # fail to do anything. Capybara doesn't raise an error, so it thinks it's
  # clicked the button, but nothing appears to happen.
  #
  # As a workaround, find the element and programmatically trigger a click
  # event on it, which seems to be more reliable.
  #
  # See: https://github.com/teampoltergeist/poltergeist/issues/530
  #
  # I think we've only seen this issue in these tests (and not in other parts
  # of the admin app). My theory is that this might be due to the click event
  # firing right as the stylesheets load, so the original location it
  # calculated and then clicks ends up being incorrect once the stylesheets
  # load. I'm not sure about this, but it might explain why it's only happening
  # here, and not within the app (since within the app, all the javascript and
  # stylesheets must be loaded first for there to be anything rendering on the
  # page).
  def click_server_side_link(selector)
    find_link(selector).trigger("click")
  end
end
