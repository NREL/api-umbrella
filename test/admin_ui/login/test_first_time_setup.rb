require_relative "../../test_helper"

class Test::AdminUi::Login::TestFirstTimeSetup < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth

  def setup
    setup_server
    Admin.delete_all
  end

  def test_redirects_to_signup_on_first_login
    assert_equal(0, Admin.count)
    visit "/admin/"

    assert_content("Welcome!")
    assert_content("It looks like you're setting up API Umbrella for the first time. Create your first admin account to get started.")
    assert_content("14 characters minimum")
    assert_equal("/admins/signup", page.current_path)

    fill_in "Email", :with => "new@example.com"
    fill_in "Password", :with => "password123456"
    fill_in "Password Confirmation", :with => "password123456"
    click_button "Sign up"

    # Ensure the user gets logged in.
    assert_logged_in
    assert_equal(1, Admin.count)

    # First user should be superuser.
    admin = Admin.first
    assert_equal(true, admin.superuser)
  end

  def test_redirects_to_login_if_admin_exists
    FactoryGirl.create(:admin)
    assert_equal(1, Admin.count)
    visit "/admin/"

    assert_content("Admin Sign In")
    refute_content("An initial admin account already exists.")
    assert_equal("/admin/login", page.current_path)
  end

  def test_redirects_away_from_signup_if_admin_exists
    FactoryGirl.create(:admin)
    assert_equal(1, Admin.count)
    visit "/admins/signup"

    assert_content("Admin Sign In")
    assert_content("An initial admin account already exists.")
    assert_equal("/admin/login", page.current_path)
  end

  def test_redirects_away_from_submit_if_admin_exists
    assert_equal(0, Admin.count)
    visit "/admins/signup"

    assert_content("Welcome!")
    assert_content("It looks like you're setting up API Umbrella for the first time. Create your first admin account to get started.")

    fill_in "Email", :with => "new@example.com"
    fill_in "Password", :with => "password123456"
    fill_in "Password Confirmation", :with => "password123456"

    # Insert an admin before hitting submit to ensure the submit endpoint can't
    # be hit directly.
    FactoryGirl.create(:admin)
    assert_equal(1, Admin.count)

    click_button "Sign up"

    assert_content("Admin Sign In")
    assert_content("An initial admin account already exists.")
    assert_equal("/admin/login", page.current_path)

    assert_equal(1, Admin.count)
  end

  def test_allows_admin_creation_if_no_admin_exists
    assert_first_time_admin_creation_allowed
  end

  def test_forbids_admin_creation_if_admin_exists
    FactoryGirl.create(:admin)
    assert_first_time_admin_creation_forbidden
  end
end
