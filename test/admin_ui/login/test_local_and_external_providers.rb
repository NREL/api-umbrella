require_relative "../../test_helper"

class Test::AdminUi::Login::TestLocalAndExternalProviders < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth
  include Minitest::Hooks

  def setup
    setup_server
    Admin.delete_all
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
      }, ["--router", "--web"])
    end
  end

  def after_all
    super
    override_config_reset(["--router", "--web"])
  end

  def test_allows_first_time_admin_creation
    assert_equal(0, Admin.count)
    assert_first_time_admin_creation_allowed
  end

  def test_shows_local_login_fields_and_external_login_links
    FactoryGirl.create(:admin)
    visit "/admin/login"

    assert_content("Admin Sign In")

    # Local login fields
    assert_field("Email")
    assert_field("Password")
    assert_field("Remember me")
    assert_link("Forgot your password?")
    assert_button("Sign in")

    # External login links
    assert_content("Sign in with")

    buttons = page.all(".external-login .btn").map { |btn| btn.text }
    assert_equal(["Sign in with Google"], buttons)
  end
end
