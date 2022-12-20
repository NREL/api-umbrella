require_relative "../test_helper"

class Test::StaticSite::TestContact < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::SentEmails

  def setup
    super
    setup_server

    clear_all_test_emails
  end

  def test_submission
    visit "/contact/"
    assert_text("Contact us directly")

    fill_in "Name", :with => "Foo"
    fill_in "Email", :with => "foo@example.com"
    fill_in "Which API are you inquiring about?", :with => "My API"
    select "Other", :from => "What can we help you with?"
    fill_in "Message", :with => "Test message"
    click_button "Send"

    assert_text("Thanks for sending your message. We'll be in touch.")

    messages = sent_emails
    assert_equal(1, messages.fetch("total"))
  end
end
