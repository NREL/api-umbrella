require_relative "../../../test_helper"

class TestApisV1UsersServerSideTimestamps < Minitest::Capybara::Test
  include ApiUmbrellaTests::AdminAuth
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
    ApiUser.where(:registration_source.ne => "seed").delete_all
  end

  def test_create
    attributes = FactoryGirl.attributes_for(:api_user)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", @@http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_equal(201, response.code, response.body)
    assert_server_side_timestamp(response)
  end

  def test_update
    record = FactoryGirl.create(:api_user)
    attributes = record.serializable_hash
    attributes["use_description"] = rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", @@http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_equal(200, response.code, response.body)
    assert_server_side_timestamp(response)
  end

  private

  def assert_server_side_timestamp(response)
    data = MultiJson.load(response.body)
    user = ApiUser.find(data["user"]["id"])
    assert_kind_of(BSON::Timestamp, user[:ts])
    assert_in_delta(Time.now.utc.to_i, user[:ts].seconds, 2)
    assert_kind_of(Numeric, user[:ts].increment)
  end
end
