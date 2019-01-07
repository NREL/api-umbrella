require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestCreateWelcomeEmail < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::SentEmails

  def setup
    super
    setup_server

    response = Typhoeus.delete("http://127.0.0.1:#{$config["mailhog"]["api_port"]}/api/v1/messages")
    assert_response_code(200, response)
  end

  def test_sends_email_when_enabled
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :send_welcome_email => true },
      },
    }))
    assert_response_code(201, response)
    assert_equal(1, sent_emails.length)
  end

  def test_no_email_when_disabled
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :send_welcome_email => false },
      },
    }))
    assert_response_code(201, response)
    assert_equal(0, sent_emails.length)
  end

  def test_no_email_when_unknown_value
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :send_welcome_email => 1 },
      },
    }))
    assert_response_code(201, response)
    assert_equal(0, sent_emails.length)
  end

  def test_no_email_by_default
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
      },
    }))
    assert_response_code(201, response)
    assert_equal(0, sent_emails.length)
  end

  def test_sends_email_when_user_attribute_has_any_value
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user).merge({
          :send_welcome_email => "0",
        }),
      },
    }))
    assert_response_code(201, response)
    assert_equal(1, sent_emails.length)
  end

  def test_default_content
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :send_welcome_email => true },
      },
    }))
    assert_response_code(201, response)

    messages = sent_emails
    assert_equal(1, messages.length)

    data = MultiJson.load(response.body)
    user = ApiUser.find(data["user"]["id"])
    message = messages.first

    # To
    refute_nil(user.email)
    assert_equal([user.email], message["Content"]["Headers"]["To"])

    # API key
    refute_nil(user.api_key)
    assert_match(user.api_key, message["_mime_parts"]["text/html"]["_body"])
    assert_match(user.api_key, message["_mime_parts"]["text/plain"]["_body"])

    # Subject
    assert_equal(["Your API Umbrella API key"], message["Content"]["Headers"]["Subject"])

    # From
    assert_equal(["noreply@localhost"], message["Content"]["Headers"]["From"])

    # Example API URL
    refute_match("Here's an example", message["_mime_parts"]["text/html"]["_body"])
    refute_match("Here's an example", message["_mime_parts"]["text/plain"]["_body"])

    # Contact URL
    assert_match(%(<a href="http://localhost/contact/">contact us</a>), message["_mime_parts"]["text/html"]["_body"])
    assert_match("contact us ( http://localhost/contact/ )", message["_mime_parts"]["text/plain"]["_body"])
  end

  def test_customized_content
    prepend_api_backends([
      {
        :frontend_host => "example.com",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => {
          :user => FactoryBot.attributes_for(:api_user),
          :options => {
            :send_welcome_email => true,
            :site_name => "External Example",
            :email_from_name => "Tester",
            :email_from_address => "test@example.com",
            :example_api_url => "https://example.com/api.json?api_key={{api_key}}&test=1",
            :contact_url => "https://example.com/contact-us",
          },
        },
      }))
      assert_response_code(201, response)

      messages = sent_emails
      assert_equal(1, messages.length)

      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      message = messages.first

      # To
      refute_nil(user.email)
      assert_equal([user.email], message["Content"]["Headers"]["To"])

      # API key
      refute_nil(user.api_key)
      assert_match(user.api_key, message["_mime_parts"]["text/html; charset=UTF-8"]["Body"])
      assert_match(user.api_key, message["_mime_parts"]["text/plain; charset=UTF-8"]["Body"])

      # Subject
      assert_equal(["Your External Example API key"], message["Content"]["Headers"]["Subject"])

      # From
      assert_equal(["Tester <test@example.com>"], message["Content"]["Headers"]["From"])

      # URL Example
      assert_match("Here's an example", message["_mime_parts"]["text/html; charset=UTF-8"]["Body"])
      assert_match("Here's an\r\nexample", message["_mime_parts"]["text/plain; charset=UTF-8"]["Body"])
      assert_match(%(<a href="https://example.com/api.json?api_key=#{user.api_key}&amp;test=1">https://example.com/api.json?<strong>api_key=#{user.api_key}</strong>&amp;test=1</a>), message["_mime_parts"]["text/html; charset=UTF-8"]["Body"])
      assert_match("https://example.com/api.json?api_key=#{user.api_key}&test=1\r\n\r\n( https://example.com/api.json?api_key=#{user.api_key}&test=1 )", message["_mime_parts"]["text/plain; charset=UTF-8"]["Body"])

      # Contact URL
      assert_match(%(<a href="https://example.com/contact-us">contact us</a>), message["_mime_parts"]["text/html; charset=UTF-8"]["Body"])
      assert_match("contact us \r\n( https://example.com/contact-us )", message["_mime_parts"]["text/plain; charset=UTF-8"]["Body"])
    end
  end

  def test_sanitize
  end
end
