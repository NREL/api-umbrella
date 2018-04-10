require_relative "../../../test_helper"

class Test::Apis::V1::Contact::TestEmail < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::DelayedJob

  def setup
    super
    setup_server

    response = Typhoeus.delete("http://127.0.0.1:#{$config["mailhog"]["api_port"]}/api/v1/messages")
    assert_response_code(200, response)
  end

  def test_sends_email
    user = FactoryBot.create(:api_user, {
      :roles => ["api-umbrella-contact-form"],
    })

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/contact.json", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user["api_key"],
        "Content-Type" => "application/x-www-form-urlencoded",
      },
      :body => {
        :contact => {
          :name => "Foo",
          :email => "foo@example.com",
          :api => "Example API",
          :subject => "Support",
          :message => "Message body",
        },
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(["submitted"], data.keys)

    messages = delayed_job_sent_messages
    assert_equal(1, messages.length)
    message = messages.first

    assert_equal(["default-test-contact-email@example.com"], message["Content"]["Headers"]["To"])
    assert_equal(["API Umbrella Contact Message from foo@example.com"], message["Content"]["Headers"]["Subject"])
    assert_equal(["noreply@localhost"], message["Content"]["Headers"]["From"])
    assert_equal(["foo@example.com"], message["Content"]["Headers"]["Reply-To"])
    assert_equal(["text/plain; charset=UTF-8"], message["Content"]["Headers"]["Content-Type"])
    assert_equal("Name: Foo\r\nEmail: foo@example.com\r\nAPI: Example API\r\nSubject: Support\r\n\r\n-------------------------------------\r\n\r\nMessage body\r\n\r\n-------------------------------------", message["Content"]["Body"])
  end
end
