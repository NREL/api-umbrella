require_relative "../../test_helper"

class Test::AdminUi::Login::TestExternalProviders < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth
  include Minitest::Hooks

  def setup
    super
    setup_server
    Admin.delete_all
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
    assert_first_time_admin_creation_forbidden
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
      :username_path => "info.email",
      :verified_path => "info.verified",
    },
    {
      :provider => :github,
      :login_button_text => "Sign in with GitHub",
      :username_path => "info.email",
    },
    {
      :provider => :gitlab,
      :login_button_text => "Sign in with GitLab",
      :username_path => "info.email",
    },
    {
      :provider => :google_oauth2,
      :login_button_text => "Sign in with Google",
      :username_path => "info.email",
      :verified_path => "extra.raw_info.email_verified",
    },
    {
      :provider => :ldap,
      :login_button_text => "Sign in with LDAP",
      :username_path => "extra.raw_info.sAMAccountName",
    },
    {
      :provider => :cas,
      :login_button_text => "Sign in with MAX.gov",
      :username_path => "uid",
      :extra => {
        "extra" => {
          "MaxSecurityLevel" => "standard, securePlus2",
        },
      },
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

    if(options[:verified_path])
      define_method("test_#{options.fetch(:provider)}_unverified_email") do
        assert_login_unverified_email_login(options)
      end
    end
  end

  private

  def assert_login_valid_admin(options)
    admin = FactoryBot.create(:admin, :username => "valid@example.com")
    omniauth_data = omniauth_base_data(options)
    LazyHash.add(omniauth_data, options.fetch(:username_path), admin.username)

    mock_omniauth(omniauth_data) do
      assert_login_permitted(options.fetch(:login_button_text), admin)
    end
  end

  def assert_login_case_insensitive_username_admin(options)
    admin = FactoryBot.create(:admin, :username => "hello@example.com")
    omniauth_data = omniauth_base_data(options)
    LazyHash.add(omniauth_data, options.fetch(:username_path), "Hello@ExamplE.Com")

    mock_omniauth(omniauth_data) do
      assert_login_permitted(options.fetch(:login_button_text), admin)
    end
  end

  def assert_login_nonexistent_admin(options)
    omniauth_data = omniauth_base_data(options)
    LazyHash.add(omniauth_data, options.fetch(:username_path), "noadmin@example.com")

    mock_omniauth(omniauth_data) do
      assert_login_forbidden(options.fetch(:login_button_text), "not authorized")
    end
  end

  def assert_login_unverified_email_login(options)
    admin = FactoryBot.create(:admin, :username => "unverified@example.com")
    omniauth_data = omniauth_base_data(options)
    LazyHash.add(omniauth_data, options.fetch(:username_path), admin.username)
    LazyHash.add(omniauth_data, options.fetch(:verified_path), false)

    mock_omniauth(omniauth_data) do
      assert_login_forbidden(options.fetch(:login_button_text), "not verified")
    end
  end

  def assert_login_permitted(login_button_text, admin)
    visit "/admin/"
    trigger_click_link(login_button_text)
    assert_link("my_account_nav_link", :href => /#{admin.id}/, :visible => :all)
  end

  def assert_login_forbidden(login_button_text, error_text)
    visit "/admin/"
    trigger_click_link(login_button_text)
    assert_text(error_text)
    refute_link("my_account_nav_link")
  end

  def omniauth_base_data(options)
    omniauth_base_data = LazyHash.build_hash
    omniauth_base_data["provider"] = options.fetch(:provider).to_s
    if(options[:verified_path])
      LazyHash.add(omniauth_base_data, options.fetch(:verified_path), true)
    end

    if(options[:extra])
      omniauth_base_data.deep_merge!(options[:extra])
    end

    omniauth_base_data
  end

  def mock_omniauth(omniauth_data)
    # Reset the session and clear caches before setting our cookie. For some
    # reason this seems necessary to ensure click_link always works correctly
    # (otherwise, we sporadically get failures caused by the click_link on the
    # login buttons not actually going anywhere).
    #
    # Possibly related:
    # https://github.com/teampoltergeist/poltergeist/issues/814#issuecomment-248830334
    Capybara.reset_session!
    page.driver.clear_memory_cache

    # Set a cookie to mock the OmniAuth responses. This relies on the
    # TestMockOmniauth middleware we install into the Rails app during the test
    # environment. This gives us a way to mock this data from outside the Rails
    # test suite.
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
  def trigger_click_link(selector)
    find_link(selector).trigger("click")
  end
end
