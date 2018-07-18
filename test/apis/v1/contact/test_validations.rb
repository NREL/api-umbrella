require_relative "../../../test_helper"

class Test::Apis::V1::Contact::TestValidations < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_required
    response = make_request({})
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide your first name.",
        "field" => "name",
        "full_message" => "Name: Provide your first name.",
      },
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide your email address.",
        "field" => "email",
        "full_message" => "Email: Provide your email address.",
      },
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide the API.",
        "field" => "api",
        "full_message" => "Api: Provide the API.",
      },
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide a subject.",
        "field" => "subject",
        "full_message" => "Subject: Provide a subject.",
      },
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide a message.",
        "field" => "message",
        "full_message" => "Message: Provide a message.",
      },
    ].sort_by { |e| e["full_message"] }, data["errors"].sort_by { |e| e["full_message"] })
  end

  def test_email_format
    response = make_request({
      :name => "Foo",
      :email => "foo@example",
      :api => "Example API",
      :subject => "Support",
      :message => "Message body",
    })
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide a valid email address.",
        "field" => "email",
        "full_message" => "Email: Provide a valid email address.",
      },
    ], data["errors"])
  end

  private

  def make_request(attributes)
    user = FactoryBot.create(:api_user, {
      :roles => ["api-umbrella-contact-form"],
    })

    Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/contact.json", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user["api_key"],
        "Content-Type" => "application/x-www-form-urlencoded",
      },
      :body => {
        :contact => attributes,
      },
    }))
  end
end
