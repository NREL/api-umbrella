require_relative "../test_helper"

class Test::StaticSite::TestSignup < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::DelayedJob

  def setup
    super
    setup_server
    ApiUser.where(:registration_source.ne => "seed").delete_all

    response = Typhoeus.delete("http://127.0.0.1:#{$config["mailhog"]["api_port"]}/api/v1/messages")
    assert_response_code(200, response)
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

    user = ApiUser.order_by(:created_at.asc).last
    assert(user)
    assert(user.api_key)
    assert_equal("foo@example.com", user.email)
    assert_text(user.api_key)

    messages = delayed_job_sent_messages
    assert_equal(1, messages.length)
  end
end
