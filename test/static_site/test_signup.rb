require_relative "../test_helper"

class Test::StaticSite::TestSignup < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::SentEmails

  def setup
    super
    setup_server

    clear_all_test_emails
  end

  def test_submission
    visit "/signup/"
    assert_text("API Key Signup")

    fill_in "First Name", :with => "Foo"
    fill_in "Last Name", :with => "Bar"
    fill_in "Email", :with => "foo@example.com"
    check "I have read and agree to the terms and conditions."
    click_button "Signup"

    assert_text("Your API key for foo@example.com is:")

    user = ApiUser.order(:created_at => :asc).last
    assert(user)
    assert(user.api_key)
    assert_equal("foo@example.com", user.email)
    assert_text(user.api_key)

    messages = sent_emails
    assert_equal(1, messages.fetch("total"))
  end
end
