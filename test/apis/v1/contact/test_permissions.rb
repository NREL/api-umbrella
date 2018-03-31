require_relative "../../../test_helper"

class Test::Apis::V1::Contact::TestPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_forbids_api_key_without_role
    user = FactoryBot.create(:api_user, {
      :roles => ["xapi-umbrella-contact-form", "api-umbrella-contact-formx"],
    })

    response = make_request(user)
    assert_response_code(401, response)
  end

  def test_allows_api_key_with_role
    user = FactoryBot.create(:api_user, {
      :roles => ["api-umbrella-contact-form"],
    })

    response = make_request(user)
    assert_response_code(200, response)
  end

  private

  def make_request(user)
    Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/contact.json", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user.api_key,
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
  end
end
