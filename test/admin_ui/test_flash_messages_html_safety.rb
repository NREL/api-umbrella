require_relative "../test_helper"

class Test::AdminUi::TestFlashMessagesHtmlSafety < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminUiLogin
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        # While the contact URL should be trusted, since it's configured by an
        # admin, still test with special character to ensure it's escaped
        # properly.
        "contact_url" => "https://example.com/contact/?q='\"><script>alert('hello')</script>",
        "web" => {
          "admin" => {
            "auth_strategies" => {
              "enabled" => [
                "google",
                "max.gov",
              ],
              "max.gov" => {
                "require_mfa" => true,
              },
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

  def test_unverified_html_message
    omniauth_data = {
      "provider" => "google_oauth2",
      "info" => {
        "email" => "unverified@example.com",
      },
      "extra" => {
        "raw_info" => {
          "email_verified" => false,
        },
      },
    }

    mock_omniauth(omniauth_data) do
      assert_login_forbidden("Sign in with Google", "not verified")
      assert_match("The email address 'unverified@example.com' is not verified. Please <a href=\"https://example.com/contact/?q='&quot;&gt;&lt;script&gt;alert('hello')&lt;/script&gt;\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_unverified_html_message_with_xss_email
    omniauth_data = {
      "provider" => "google_oauth2",
      "info" => {
        "email" => "'\"><script>alert('hello')</script>",
      },
      "extra" => {
        "raw_info" => {
          "email_verified" => false,
        },
      },
    }

    mock_omniauth(omniauth_data) do
      assert_login_forbidden("Sign in with Google", "not verified")
      assert_match("The email address ''\"&gt;&lt;script&gt;alert('hello')&lt;/script&gt;' is not verified. Please <a href=\"https://example.com/contact/?q='&quot;&gt;&lt;script&gt;alert('hello')&lt;/script&gt;\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_nonexistent_html_message
    omniauth_data = {
      "provider" => "google_oauth2",
      "info" => {
        "email" => "noadmin@example.com",
      },
      "extra" => {
        "raw_info" => {
          "email_verified" => true,
        },
      },
    }

    mock_omniauth(omniauth_data) do
      assert_login_forbidden("Sign in with Google", "not authorized")
      assert_match("The account for 'noadmin@example.com' is not authorized to access the admin. Please <a href=\"https://example.com/contact/?q='&quot;&gt;&lt;script&gt;alert('hello')&lt;/script&gt;\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_nonexistent_html_message_with_xss_email
    omniauth_data = {
      "provider" => "google_oauth2",
      "info" => {
        "email" => "'\"><script>alert('hello')</script>",
      },
      "extra" => {
        "raw_info" => {
          "email_verified" => true,
        },
      },
    }

    mock_omniauth(omniauth_data) do
      assert_login_forbidden("Sign in with Google", "not authorized")
      assert_match("The account for ''\"&gt;&lt;script&gt;alert('hello')&lt;/script&gt;' is not authorized to access the admin. Please <a href=\"https://example.com/contact/?q='&quot;&gt;&lt;script&gt;alert('hello')&lt;/script&gt;\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_mfa_required_html_message
    omniauth_data = {
      "provider" => "cas",
      "info" => {
        "email" => "noadmin@example.com",
      },
    }

    mock_omniauth(omniauth_data) do
      assert_login_forbidden("Sign in with MAX.gov", "must use multi-factor")
      assert_match("You must use multi-factor authentication to sign in. Please try again, or <a href=\"https://example.com/contact/?q='&quot;&gt;&lt;script&gt;alert('hello')&lt;/script&gt;\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_error_message_from_external_provider
    visit "/admins/auth/google_oauth2/callback?error='\"><script>confirm(document.domain)</script>"
    assert_match("Could not authenticate you from GoogleOauth2 because \"'\"&gt;&lt;script&gt;confirm(document.domain)&lt;/script&gt;\".", page.body)
  end
end
