require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestCreateNotifyEmail < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::DelayedJob

  def setup
    super
    setup_server
    ApiUser.where(:registration_source.ne => "seed").delete_all

    response = Typhoeus.delete("http://127.0.0.1:#{$config["mailhog"]["api_port"]}/api/v1/messages")
    assert_response_code(200, response)
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
    assert_equal(1, delayed_job_sent_messages.length)
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
    assert_equal(0, delayed_job_sent_messages.length)
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
    assert_equal(0, delayed_job_sent_messages.length)
  end

  def test_no_email_by_default
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
      },
    }))
    assert_response_code(201, response)
    assert_equal(0, delayed_job_sent_messages.length)
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

    messages = delayed_job_sent_messages
    assert_equal(1, messages.length)

    data = MultiJson.load(response.body)
    user = ApiUser.find(data["user"]["id"])
    message = messages.first

    # To
    assert_equal(["default-test-contact-email@example.com"], message["Content"]["Headers"]["To"])

    # Subject
    assert_equal(["#{user.first_name} #{user.last_name} just subscribed"], message["Content"]["Headers"]["Subject"])

    # Use description in body
    assert_match("I wanna do everything.", message["_mime_parts"]["text/html; charset=UTF-8"]["Body"])
    assert_match("I wanna do everything.", message["_mime_parts"]["text/plain; charset=UTF-8"]["Body"])
  end

  def test_global_config_enabling_by_default
    config = {
      "web" => {
        "admin_notify_email" => "notify-only@example.com",
        "send_notify_email" => true,
      },
    }
    override_config(config, nil) do
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => {
          :user => FactoryBot.attributes_for(:api_user),
        },
      }))
      assert_response_code(201, response)

      messages = delayed_job_sent_messages
      assert_equal(1, messages.length)

      message = messages.first

      # To
      assert_equal(["notify-only@example.com"], message["Content"]["Headers"]["To"])
    end
  end
end
