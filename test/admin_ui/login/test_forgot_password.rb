require_relative "../../test_helper"

class Test::AdminUi::Login::TestForgotPassword < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::SentEmails

  def setup
    super
    setup_server

    clear_all_test_emails
  end

  def test_non_existent_email
    visit "/admins/password/new"

    fill_in "Email", :with => "foobar@example.com"
    click_button "Send me reset password instructions"
    assert_text("If your email address exists in our database, you will receive a password recovery link at your email address in a few minutes.")

    assert_equal(0, sent_emails.fetch("total"))
  end

  def test_reset_process
    admin = FactoryBot.create(:admin, :username => "admin@example.com")
    assert_nil(admin.reset_password_token_hash)
    assert_nil(admin.reset_password_sent_at)
    original_password_hash = admin.password_hash
    assert(original_password_hash)

    visit "/admins/password/new"

    # Reset password
    fill_in "Email", :with => "admin@example.com"
    click_button "Send me reset password instructions"
    assert_text("If your email address exists in our database, you will receive a password recovery link at your email address in a few minutes.")

    # Check for reset token on database record.
    admin.reload
    assert(admin.reset_password_token_hash)
    assert(admin.reset_password_sent_at)
    assert_equal(original_password_hash, admin.password_hash)

    # Find sent email
    messages = sent_email_contents
    assert_equal(1, messages.fetch("total"))
    message = messages.fetch("messages").first

    # To
    assert_equal(["admin@example.com"], message.fetch("headers").fetch("To"))

    # Subject
    assert_equal("Reset password instructions", message.fetch("Subject"))

    # Password reset URL in body
    assert_match(%r{https://127.0.0.1:9081/admins/password/edit\?reset_password_token=[^"]+}, message.fetch("HTML"))
    assert_match(%r{https://127.0.0.1:9081/admins/password/edit\?reset_password_token=[^"]+}, message.fetch("Text"))

    # Follow link to reset URL
    reset_url = message.fetch("HTML").match(%r{/admins/password/edit\?reset_password_token=[^"]+})[0]
    visit reset_url

    assert_text("Change Your Password")
    assert_text("14 characters minimum")

    # Too short password
    fill_in "New Password", :with => "short"
    fill_in "Confirm New Password", :with => "short"
    click_button "Change My Password"
    assert_text("is too short (minimum is 14 characters)")
    admin.reload
    assert_equal(original_password_hash, admin.password_hash)

    # Mismatched password
    fill_in "New Password", :with => "mismatch123456"
    fill_in "Confirm New Password", :with => "mismatcH123456"
    click_button "Change My Password"
    assert_text("doesn't match Password")
    admin.reload
    assert_equal(original_password_hash, admin.password_hash)

    # Valid password
    fill_in "New Password", :with => "password123456"
    fill_in "Confirm New Password", :with => "password123456"
    click_button "Change My Password"

    # Ensure the user gets logged in.
    assert_logged_in(admin)

    # Check for database record updates.
    admin.reload
    assert_nil(admin.reset_password_token_hash)
    assert_nil(admin.reset_password_sent_at)
    assert(admin.password_hash)
    refute_equal(original_password_hash, admin.password_hash)
  end
end
