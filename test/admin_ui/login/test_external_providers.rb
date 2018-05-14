require_relative "../../test_helper"

class Test::AdminUi::Login::TestExternalProviders < Minitest::Capybara::Test
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
        "web" => {
          "admin" => {
            "auth_strategies" => {
              "enabled" => [
                "facebook",
                "max.gov",
                "github",
                "gitlab",
                "google",
                "ldap",
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

  def test_forbids_first_time_admin_creation
    assert_equal(0, Admin.count)
    assert_first_time_admin_creation_not_found
  end

  def test_shows_message_when_no_admins_exist
    assert_equal(0, Admin.count)
    visit "/admin/login"
    assert_text("No admins currently exist")
  end

  def test_shows_external_login_links_in_order_and_no_local_fields
    visit "/admin/login"

    assert_text("Admin Sign In")

    # No local login fields
    refute_field("Email")
    refute_field("Password")
    refute_field("Remember me")
    refute_link("Forgot your password?")
    refute_button("Sign in")

    # External login links
    assert_text("Sign in with")

    # Order matches enabled array order.
    buttons = page.all(".external-login .btn").map { |btn| btn.text }
    assert_equal([
      "Sign in with Facebook",
      "Sign in with MAX.gov",
      "Sign in with GitHub",
      "Sign in with GitLab",
      "Sign in with Google",
      "Sign in with LDAP",
    ], buttons)
  end

  def test_local_login_endpoint_disabled
    admin = FactoryBot.create(:admin)
    response = Typhoeus.post("https://127.0.0.1:9081/admin/login", keyless_http_options.deep_merge(csrf_session).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :admin => {
          :username => admin.username,
          :password => "password123456",
        },
      },
    }))
    assert_response_code(404, response)
  end

  def test_no_password_field_on_admin_forms
    assert_no_password_fields_on_admin_forms
  end

  [
    {
      :provider => :facebook,
      :login_button_text => "Sign in with Facebook",
      :mock_userinfo => MultiJson.dump({
        "email" => "{{username}}",
        "verified" => true,
      }),
      :mock_userinfo_unverified => MultiJson.dump({
        "email" => "{{username}}",
        "verified" => false,
      }),
    },
    {
      :provider => :github,
      :login_button_text => "Sign in with GitHub",
      :mock_userinfo => MultiJson.dump([
        {
          "email" => "other-email@example.com",
          "primary" => false,
          "verified" => true,
        },
        {
          "email" => "{{username}}",
          "primary" => true,
          "verified" => true,
        },
      ]),
      :mock_userinfo_unverified => MultiJson.dump([
        {
          "email" => "other-email@example.com",
          "primary" => false,
          "verified" => true,
        },
        {
          "email" => "{{username}}",
          "primary" => true,
          "verified" => false,
        },
      ]),
    },
    {
      :provider => :gitlab,
      :login_button_text => "Sign in with GitLab",
      :mock_userinfo => MultiJson.dump({
        "email" => "{{username}}",
      }),
    },
    {
      :provider => :google_oauth2,
      :login_button_text => "Sign in with Google",
      :mock_userinfo => MultiJson.dump({
        "email" => "{{username}}",
        "email_verified" => true,
      }),
      :mock_userinfo_unverfied => MultiJson.dump({
        "email" => "{{username}}",
        "email_verified" => false,
      }),
    },
    {
      :provider => :ldap,
      :login_button_text => "Sign in with LDAP",
      :mock_userinfo => MultiJson.dump({
        "sAMAccountName" => "{{username}}",
      }),
    },
    {
      :provider => :cas,
      :login_button_text => "Sign in with MAX.gov",
      :mock_userinfo => <<~EOS
        <cas:serviceResponse xmlns:cas="http://www.yale.edu/tp/cas">
          <cas:authenticationSuccess>
            <cas:user>{{username}}</cas:user>
          </cas:authenticationSuccess>
        </cas:serviceResponse>
      EOS
    },
  ].each do |options|
    define_method("test_#{options.fetch(:provider)}_valid_admin") do
      assert_login_valid_admin(options)
    end

    define_method("test_#{options.fetch(:provider)}_case_insensitive_username_admin") do
      assert_login_case_insensitive_username_admin(options)
    end

    define_method("test_#{options.fetch(:provider)}_nonexistent_admin") do
      assert_login_nonexistent_admin(options)
    end

    if(options[:mock_userinfo_unverified])
      define_method("test_#{options.fetch(:provider)}_unverified_email") do
        assert_login_unverified_email_login(options)
      end
    end
  end

  private

  def assert_login_valid_admin(options)
    admin = FactoryBot.create(:admin, :username => "valid@example.com")
    data = options.fetch(:mock_userinfo).gsub("{{username}}", admin.username)

    mock_userinfo(data) do
      assert_login_permitted(options.fetch(:login_button_text), admin)
    end
  end

  def assert_login_case_insensitive_username_admin(options)
    admin = FactoryBot.create(:admin, :username => "hello@example.com")
    data = options.fetch(:mock_userinfo).gsub("{{username}}", "Hello@ExamplE.Com")

    mock_userinfo(data) do
      assert_login_permitted(options.fetch(:login_button_text), admin)
    end
  end

  def assert_login_nonexistent_admin(options)
    data = options.fetch(:mock_userinfo).gsub("{{username}}", "noadmin@example.com")

    mock_userinfo(data) do
      assert_login_forbidden(options.fetch(:login_button_text), "not authorized")
    end
  end

  def assert_login_unverified_email_login(options)
    admin = FactoryBot.create(:admin, :username => "unverified@example.com")
    data = options.fetch(:mock_userinfo_unverified).gsub("{{username}}", admin.username)

    mock_userinfo(data) do
      assert_login_forbidden(options.fetch(:login_button_text), "not verified")
    end
  end
end
