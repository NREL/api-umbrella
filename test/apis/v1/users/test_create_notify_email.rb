require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestCreateNotifyEmail < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::SentEmails

  def setup
    super
    setup_server

    clear_all_test_emails
  end

  def test_sends_email_when_enabled
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :send_notify_email => true },
      },
    }))
    assert_response_code(201, response)
    assert_equal(1, sent_emails.fetch("total"))
  end

  def test_no_email_when_disabled
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :send_notify_email => false },
      },
    }))
    assert_response_code(201, response)
    assert_equal(0, sent_emails.fetch("total"))
  end

  def test_no_email_when_unknown_value
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :send_notify_email => 1 },
      },
    }))
    assert_response_code(201, response)
    assert_equal(0, sent_emails.fetch("total"))
  end

  def test_no_email_by_default
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
      },
    }))
    assert_response_code(201, response)
    assert_equal(0, sent_emails.fetch("total"))
  end

  def test_content
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user, :use_description => "I wanna do everything."),
        :options => { :send_notify_email => true },
      },
    }))
    assert_response_code(201, response)

    messages = sent_email_contents
    assert_equal(1, messages.fetch("total"))

    data = MultiJson.load(response.body)
    user = ApiUser.find(data["user"]["id"])
    message = messages.fetch("messages").first

    # To
    assert_equal(["default-test-contact-email@example.com"], message.fetch("headers").fetch("To"))

    # Subject
    assert_equal("#{user.first_name} #{user.last_name} just subscribed", message.fetch("Subject"))

    # Use description in body
    assert_match("I wanna do everything.", message.fetch("HTML"))
    assert_match("I wanna do everything.", message.fetch("Text"))
  end

  def test_global_config_enabling_by_default
    config = {
      "web" => {
        "admin_notify_email" => "notify-only@example.com",
        "send_notify_email" => true,
      },
    }
    override_config(config) do
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => {
          :user => FactoryBot.attributes_for(:api_user),
        },
      }))
      assert_response_code(201, response)

      messages = sent_email_contents
      assert_equal(1, messages.fetch("total"))

      message = messages.fetch("messages").first

      # To
      assert_equal(["notify-only@example.com"], message.fetch("headers").fetch("To"))
    end
  end
end
