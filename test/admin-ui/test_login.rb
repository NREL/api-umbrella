require_relative "../test_helper"

class TestAdminUiLogin < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    Admin.delete_all
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
    click_link(login_button_text)
    assert_link("my_account_nav_link", :href => /#{admin.id}/, :visible => :all)
  end

  def assert_login_forbidden(login_button_text)
    visit "/admin/"
    click_link(login_button_text)
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
end
