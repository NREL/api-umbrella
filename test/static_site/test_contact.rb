require_relative "../test_helper"

class Test::StaticSite::TestContact < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::DelayedJob

  def setup
    super
    setup_server

    response = Typhoeus.delete("http://127.0.0.1:#{$config["mailhog"]["api_port"]}/api/v1/messages")
    assert_response_code(200, response)
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

    messages = delayed_job_sent_messages
    assert_equal(1, messages.length)
  end
end
