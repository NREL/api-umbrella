require_relative "../../../test_helper"

class TestApisV1UsersUpdate < Minitest::Capybara::Test
  include ApiUmbrellaTests::AdminAuth
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
    ApiUser.where(:registration_source.ne => "seed").delete_all
  end

  def test_valid_update
    user = FactoryGirl.create(:api_user)

    attributes = user.serializable_hash
    attributes["first_name"] = "Updated"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", @@http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_equal(200, response.code, response.body)

    data = MultiJson.load(response.body)
    assert_equal("Updated", data["user"]["first_name"])

    user = ApiUser.find(user.id)
    assert_equal("Updated", user.first_name)
  end

  def test_does_not_replace_existing_registration_source
    user = FactoryGirl.create(:api_user, :registration_source => "something")

    attributes = user.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", @@http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_equal(200, response.code, response.body)

    data = MultiJson.load(response.body)
    assert_equal("something", data["user"]["registration_source"])

    user = ApiUser.find(user.id)
    assert_equal("something", user.registration_source)
  end
end
