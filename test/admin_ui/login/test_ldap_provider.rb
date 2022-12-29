require_relative "../../test_helper"

class Test::AdminUi::Login::TestLdapProvider < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth
  include Minitest::Hooks

  def setup
    super
    setup_server

    @default_config = {
      "web" => {
        "admin" => {
          "username_is_email" => false,
          "auth_strategies" => {
            "enabled" => [
              "ldap",
            ],
            "ldap" => {
              "options" => {
                "title" => "Planet Express",
                "host" => "127.0.0.1",
                "port" => $config["glauth"]["port"],
                "base" => "dc=planetexpress,dc=com",
                "uid" => "uid",
                "method" => "plain",
                "bind_dn" => "uid=admin,dc=planetexpress,dc=com",
                "password" => "admin",
              },
            },
          },
        },
      },
    }
    once_per_class_setup do
      override_config_set(@default_config)
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_forbids_first_time_admin_creation
    assert_equal(0, Admin.count)
    assert_first_time_admin_creation_not_found
  end

  def test_ldap_login_fields_on_login_page_when_exclusive_provider
    visit "/admin/login"

    assert_text("Admin Sign In")

    # No local login fields
    refute_field("Email")
    refute_field("Remember me", :visible => :all)
    refute_link("Forgot your password?")

    # No external login links
    refute_text("Sign in with")

    # LDAP login fields on initial page when it's the only login option.
    assert_field("Planet Express Username")
    assert_field("Planet Express Password")
    assert_button("Sign in")
  end

  def test_forbids_ldap_user_without_admin_account
    assert_equal(0, Admin.count)
    visit "/admin/login"
    fill_in "Planet Express Username", :with => "hermes"
    fill_in "Planet Express Password", :with => "hermes"
    click_button "Sign in"
    assert_text("The account for 'hermes' is not authorized to access the admin. Please contact us for further assistance.")
  end

  def test_forbids_ldap_user_with_invalid_password
    FactoryBot.create(:admin, :username => "hermes", :email => nil, :password_hash => nil)
    visit "/admin/login"
    fill_in "Planet Express Username", :with => "hermes"
    fill_in "Planet Express Password", :with => "incorrect"
    click_button "Sign in"
    assert_text('Could not authenticate you because "Invalid credentials"')
  end

  def test_allows_valid_ldap_user
    admin = FactoryBot.create(:admin, :username => "hermes", :email => nil, :password_hash => nil)
    visit "/admin/login"
    fill_in "Planet Express Username", :with => "hermes"
    fill_in "Planet Express Password", :with => "hermes"
    click_button "Sign in"
    assert_logged_in(admin)
  end

  def test_separate_login_page_used_when_non_exclusive_provider
    override_config(@default_config.deep_merge({
      "web" => {
        "admin" => {
          "auth_strategies" => {
            "enabled" => [
              "local",
              "ldap",
            ],
          },
        },
      },
    })) do
      admin = FactoryBot.create(:admin, :username => "hermes", :email => nil, :password_hash => nil)
      visit "/admin/login"
      assert_field "Username"
      assert_field "Password"
      refute_field "Planet Express Username"
      refute_field "Planet Express Password"
      click_button "Sign in with Planet Express"
      assert_selector "h1", :text => "Sign in with Planet Express"
      assert_match(%r{/admins/auth/ldap\z}, page.current_url)
      fill_in "Planet Express Username", :with => "hermes"
      fill_in "Planet Express Password", :with => "hermes"
      click_button "Sign in"
      assert_logged_in(admin)
    end
  end
end
