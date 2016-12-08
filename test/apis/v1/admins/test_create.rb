require_relative "../../../test_helper"

class Test::Apis::V1::Admins::TestCreate < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    Admin.where(:registration_source.ne => "seed").delete_all
  end

  def test_downcases_username
    attributes = FactoryGirl.build(:admin, :username => "HELLO@example.com").serializable_hash
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_equal("HELLO@example.com", attributes["username"])
    assert_equal("hello@example.com", data["admin"]["username"])

    admin = Admin.find(data["admin"]["id"])
    assert_equal("hello@example.com", admin.username)
  end
end
