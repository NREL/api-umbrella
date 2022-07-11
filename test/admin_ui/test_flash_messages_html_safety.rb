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
                "github",
                "google",
                "max.gov",
              ],
              "max.gov" => {
                "require_mfa" => true,
              },
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

  # Verify the HTML escaping using raw curl requests, since the subsequent
  # Selenium tests may return "page.body" with some HTML entities already
  # un-encoded, which makes it trickier to verify the HTML escaping that's
  # going on.
  def test_raw_html
    data = MultiJson.dump({
      "id_token" => {
        "email" => "unverified@example.com",
        "email_verified" => false,
      },
    })

    http_opts = keyless_http_options.deep_merge(csrf_session)
    http_opts[:headers]["Cookie"] = [http_opts.fetch(:headers).fetch("Cookie"), "test_mock_userinfo=#{CGI.escape(Base64.strict_encode64(data))}"].join("; ")
    response = Typhoeus.post("https://127.0.0.1:9081/admins/auth/google_oauth2", http_opts)
    assert_response_code(302, response)
    assert_equal("https://127.0.0.1:9081/admins/auth/google_oauth2/callback", response.headers["Location"])

    response = Typhoeus.get(response.headers.fetch("Location"), keyless_http_options.deep_merge({
      :headers => {
        "Cookie" => "test_mock_userinfo=#{CGI.escape(Base64.strict_encode64(data))}",
      },
    }))
    assert_response_code(302, response)
    assert_equal("https://127.0.0.1:9081/admin/login", response.headers["Location"])

    response = Typhoeus.get(response.headers.fetch("Location"), keyless_http_options.deep_merge({
      :headers => {
        "Cookie" => [response.headers.fetch("set-cookie")].flatten.compact.join("; "),
      },
    }))
    assert_response_code(200, response)
    assert_match("The email address 'unverified@example.com' is not verified. Please <a href=\"https://example.com/contact/?q=&#039;&quot;&gt;&lt;script&gt;alert(&#039;hello&#039;)&lt;/script&gt;\">contact us</a> for further assistance.", response.body)
  end

  def test_unverified_html_message
    data = MultiJson.dump({
      "id_token" => {
        "email" => "unverified@example.com",
        "email_verified" => false,
      },
    })

    mock_userinfo(data) do
      assert_login_forbidden("Sign in with Google", "not verified")
      assert_match("The email address 'unverified@example.com' is not verified. Please <a href=\"https://example.com/contact/?q='&quot;><script>alert('hello')</script>\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_unverified_html_message_with_xss_email
    data = MultiJson.dump({
      "id_token" => {
        "email" => "'\"><script>alert('hello')</script>",
        "email_verified" => false,
      },
    })

    mock_userinfo(data) do
      assert_login_forbidden("Sign in with Google", "not verified")
      assert_match("The email address ''\"&gt;&lt;script&gt;alert('hello')&lt;/script&gt;' is not verified. Please <a href=\"https://example.com/contact/?q='&quot;><script>alert('hello')</script>\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_nonexistent_html_message
    data = MultiJson.dump({
      "id_token" => {
        "email" => "noadmin@example.com",
        "email_verified" => true,
      },
    })

    mock_userinfo(data) do
      assert_login_forbidden("Sign in with Google", "not authorized")
      assert_match("The account for 'noadmin@example.com' is not authorized to access the admin. Please <a href=\"https://example.com/contact/?q='&quot;><script>alert('hello')</script>\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_nonexistent_html_message_with_xss_email
    data = MultiJson.dump({
      "id_token" => {
        "email" => "'\"><script>alert('hello')</script>",
        "email_verified" => true,
      },
    })

    mock_userinfo(data) do
      assert_login_forbidden("Sign in with Google", "not authorized")
      assert_match("The account for ''\"&gt;&lt;script&gt;alert('hello')&lt;/script&gt;' is not authorized to access the admin. Please <a href=\"https://example.com/contact/?q='&quot;><script>alert('hello')</script>\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_mfa_required_html_message
    data = <<~EOS
      <cas:serviceResponse xmlns:cas="http://www.yale.edu/tp/cas">
        <cas:authenticationSuccess>
          <cas:user>noadmin@example.com</cas:user>
          <cas:attributes>
            <maxAttribute:MaxSecurityLevel>standard</maxAttribute:MaxSecurityLevel>
          </cas:attributes>
        </cas:authenticationSuccess>
      </cas:serviceResponse>
    EOS

    mock_userinfo(data) do
      assert_login_forbidden("Sign in with MAX.gov", "must use multi-factor")
      assert_match("You must use multi-factor authentication to sign in. Please try again, or <a href=\"https://example.com/contact/?q='&quot;><script>alert('hello')</script>\">contact us</a> for further assistance.", page.body)
    end
  end

  def test_error_message_from_external_provider
    visit "/admins/auth/github/callback?error='\"><script>confirm(document.domain)</script>"
    assert_match("Could not authenticate you because \"'\"&gt;&lt;script&gt;confirm(document.domain)&lt;/script&gt;\".", page.body)
  end
end
