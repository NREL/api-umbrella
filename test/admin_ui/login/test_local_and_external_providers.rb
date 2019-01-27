require_relative "../../test_helper"

class Test::AdminUi::Login::TestLocalAndExternalProviders < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth
  include Minitest::Hooks

  def setup
    super
    setup_server

    once_per_class_setup do
      override_config_set({
        "web" => {
          "admin" => {
            "auth_strategies" => {
              "enabled" => [
                "local",
                "google",
              ],
            },
          },
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_allows_first_time_admin_creation
    assert_equal(0, Admin.count)
    assert_first_time_admin_creation_allowed
  end

  def test_shows_local_login_fields_and_external_login_links
    FactoryBot.create(:admin)
    visit "/admin/login"

    assert_text("Admin Sign In")

    # Local login fields
    assert_field("Email")
    assert_field("Password")
    assert_field("Remember me", :visible => :all)
    assert_link("Forgot your password?")
    assert_button("Sign in")

    # External login links
    assert_text("Sign in with")

    buttons = page.all(".external-login .btn").map { |btn| btn.text }
    assert_equal(["Sign in with Google"], buttons)
  end

  def test_password_fields_only_for_my_account
    assert_password_fields_on_my_account_admin_form_only
  end

  def test_local_login_process
    admin = FactoryBot.create(:admin)
    visit "/admin/login"
    fill_in "admin_username", :with => admin.username
    fill_in "admin_password", :with => "password123456"
    click_button "sign_in"
    assert_logged_in(@admin)
  end
end
