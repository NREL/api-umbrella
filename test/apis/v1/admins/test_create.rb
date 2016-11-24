require_relative "../../../test_helper"

class Test::Apis::V1::Admins::TestCreate < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    Admin.delete_all
  end

  def test_downcases_username
    attributes = FactoryGirl.build(:admin, :username => "HELLO@example.com").serializable_hash
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_equal(201, response.code, response.body)

    data = MultiJson.load(response.body)
    assert_equal("HELLO@example.com", attributes["username"])
    assert_equal("hello@example.com", data["admin"]["username"])

    admin = Admin.find(data["admin"]["id"])
    assert_equal("hello@example.com", admin.username)
  end
end
