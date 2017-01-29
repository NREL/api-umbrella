require_relative "../test_helper"

class Test::AdminUi::TestApiUsersWelcomeEmail < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::DelayedJob

  def setup
    super
    setup_server

    response = Typhoeus.delete("http://127.0.0.1:#{$config["mailhog"]["api_port"]}/api/v1/messages")
    assert_response_code(200, response)
  end

  def test_no_email_by_default
    admin_login
    visit "/admin/#/api_users/new"

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    check "User agrees to the terms and conditions"
    click_button("Save")
    assert_text("Successfully saved the user")

    assert_equal(0, delayed_job_sent_messages.length)
  end

  def test_email_when_explicitly_requested
    admin_login
    visit "/admin/#/api_users/new"

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    check "User agrees to the terms and conditions"
    check "Send user welcome e-mail with API key information"
    click_button("Save")
    assert_text("Successfully saved the user")

    assert_equal(1, delayed_job_sent_messages.length)
  end
end
