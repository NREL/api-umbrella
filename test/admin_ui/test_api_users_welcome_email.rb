require_relative "../test_helper"

class Test::AdminUi::TestApiUsersWelcomeEmail < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::SentEmails

  def setup
    super
    setup_server

    clear_all_test_emails
  end

  def test_no_email_by_default
    admin_login
    visit "/admin/#/api_users/new"

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    label_check "User agrees to the terms and conditions"
    click_button("Save")
    assert_text("Successfully saved the user")

    assert_equal(0, sent_emails.fetch("total"))
  end

  def test_email_when_explicitly_requested
    admin_login
    visit "/admin/#/api_users/new"

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    label_check "User agrees to the terms and conditions"
    check "Send user welcome e-mail with API key information"
    click_button("Save")
    assert_text("Successfully saved the user")

    assert_equal(1, sent_emails.fetch("total"))
  end
end
