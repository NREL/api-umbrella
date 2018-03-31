require_relative "../../test_helper"

class Test::AdminUi::Login::TestInvite < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::DelayedJob

  def setup
    super
    setup_server
    Admin.delete_all
    response = Typhoeus.delete("http://127.0.0.1:#{$config["mailhog"]["api_port"]}/api/v1/messages")
    assert_response_code(200, response)
  end

  def test_defaults_to_sending_invite_for_new_accounts
    admin_login

    # Create admin
    visit "/admin/#/admins/new"
    assert_text("Add Admin")
    fill_in "Email", :with => "#{unique_test_id}@example.com"
    assert_checked_field("Send invite email")
    check "Superuser"
    click_button "Save"
    assert_text("Successfully saved the admin")

    # Logout
    ::Capybara.reset_session!
    page.driver.clear_memory_cache

    # Find admin record
    admin = Admin.where(:username => "#{unique_test_id.downcase}@example.com").first
    assert(admin)

    # Find sent email
    messages = delayed_job_sent_messages
    assert_equal(1, messages.length)
    message = messages.first

    # To
    assert_equal(["#{unique_test_id.downcase}@example.com"], message["Content"]["Headers"]["To"])

    # Subject
    assert_equal(["API Umbrella Admin Access"], message["Content"]["Headers"]["Subject"])

    # Password reset URL in body
    assert_match(%r{http://localhost/admins/password/edit\?invite=true&amp;reset_password_token=[^" ]+}, message["_mime_parts"]["text/html; charset=UTF-8"]["Body"])
    assert_match(%r{http://localhost/admins/password/edit\?invite=true&reset_password_token=[^" ]+}, message["_mime_parts"]["text/plain; charset=UTF-8"]["Body"])

    # Follow link to reset URL
    reset_url = message["_mime_parts"]["text/plain; charset=UTF-8"]["Body"].match(%r{/admins/password/edit\?invite=true&reset_password_token=[^" ]+})[0]
    visit reset_url
    fill_in "New Password", :with => "password123456"
    fill_in "Confirm New Password", :with => "password123456"
    click_button "Change My Password"

    # Ensure the user gets logged in.
    assert_logged_in(admin)
  end

  def test_invites_can_be_skipped_for_new_users
    admin_login

    # Create admin
    visit "/admin/#/admins/new"
    assert_text("Add Admin")
    fill_in "Email", :with => "#{unique_test_id}@example.com"
    uncheck "Send invite email"
    check "Superuser"
    click_button "Save"
    assert_text("Successfully saved the admin")

    # Find admin record
    admin = Admin.where(:username => "#{unique_test_id.downcase}@example.com").first
    assert(admin)

    # No email
    assert_equal(0, delayed_job_sent_messages.length)
  end

  def test_invites_can_be_resent
    admin_login

    admin = FactoryBot.create(:admin)
    assert_nil(admin.notes)

    # Ensure edits don't resend invites by default.
    visit "/admin/#/admins/#{admin.id}/edit"
    assert_text("Edit Admin")
    fill_in "Notes", :with => "Foo"
    assert_equal(false, find_field("Resend invite email").checked?)
    click_button "Save"
    assert_text("Successfully saved the admin")
    page.execute_script("window.PNotifyRemoveAll()")

    admin.reload
    assert_equal("Foo", admin.notes)
    assert_equal(0, delayed_job_sent_messages.length)

    # Force the invite to be resent.
    visit "/admin/#/admins/#{admin.id}/edit"
    assert_text("Edit Admin")
    fill_in "Notes", :with => "Bar"
    assert_equal(false, find_field("Resend invite email").checked?)
    check "Resend invite email"
    click_button "Save"
    assert_text("Successfully saved the admin")
    page.execute_script("window.PNotifyRemoveAll()")

    admin.reload
    assert_equal("Bar", admin.notes)
    messages = delayed_job_sent_messages
    assert_equal(1, messages.length)
    message = messages.first
    assert_equal(["API Umbrella Admin Access"], message["Content"]["Headers"]["Subject"])

    admin.update(:current_sign_in_at => Time.now.utc)
    visit "/admin/#/admins/#{admin.id}/edit"
    refute_field("Resend invite email")
  end
end
