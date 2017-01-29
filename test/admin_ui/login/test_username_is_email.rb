require_relative "../../test_helper"

class Test::AdminUi::Login::TestUsernameIsEmail < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth

  def setup
    setup_server
    Admin.delete_all
    @admin = FactoryGirl.create(:admin)
  end

  def test_email_label_on_login
    visit "/admin/login"
    assert_content("Admin Sign In")

    assert_content("Email")
    refute_content("Username")
  end

  def test_email_label_on_listing
    admin_login
    visit "/admin/#/admins"
    assert_content("Admins")

    assert_content("Email")
    refute_content("Username")
  end

  def test_email_label_on_form
    admin_login
    visit "/admin/#/admins/new"
    assert_content("Add Admin")

    assert_field("Email", :count => 1)
    refute_field("Username")
  end

  def test_keeps_username_and_email_in_sync
    admin_login

    # Create admin
    visit "/admin/#/admins/new"
    assert_content("Add Admin")
    fill_in "Email", :with => "#{unique_test_id.upcase}@example.com"
    check "Superuser"
    click_button "Save"
    assert_content("Successfully saved the admin")
    page.execute_script("PNotify.removeAll()")

    # Find admin record, and ensure username and email are different.
    admin = Admin.where(:username => "#{unique_test_id.downcase}@example.com").first
    assert(admin)
    assert_equal("#{unique_test_id.downcase}@example.com", admin.username)
    assert_equal(admin.username, admin.email)

    # Edit admin
    visit "/admin/#/admins/#{admin.id}/edit"
    assert_content("Edit Admin")
    assert_field("Email", :with => "#{unique_test_id.downcase}@example.com")
    fill_in "Email", :with => "#{unique_test_id.upcase}-update@example.com"
    click_button "Save"
    assert_content("Successfully saved the admin")
    page.execute_script("PNotify.removeAll()")

    # Ensure edits still keep things different.
    admin.reload
    assert_equal("#{unique_test_id.downcase}-update@example.com", admin.username)
    assert_equal(admin.username, admin.email)
  end
end
