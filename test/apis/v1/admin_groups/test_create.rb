require_relative "../../../test_helper"

class Test::Apis::V1::AdminGroups::TestCreate < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_validates_user_manage_permision
    attributes = FactoryBot.build(:admin_group, {
      :permission_ids => ["user_manage"],
    }).serializable_hash
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin_group => attributes),
    }))
    assert_response_code(422, response)

    data = MultiJson.load(response.body)
    assert_equal({
      "permission_ids" => [
        "user_view permission must be included if user_manage is enabled",
      ],
    }, data.fetch("errors"))

    attributes = FactoryBot.build(:admin_group, {
      :permission_ids => ["user_manage", "user_view"],
    }).serializable_hash
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin_group => attributes),
    }))
    assert_response_code(201, response)
  end

  def test_validates_admin_manage_permision
    attributes = FactoryBot.build(:admin_group, {
      :permission_ids => ["admin_manage"],
    }).serializable_hash
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin_group => attributes),
    }))
    assert_response_code(422, response)

    data = MultiJson.load(response.body)
    assert_equal({
      "permission_ids" => [
        "admin_view permission must be included if admin_manage is enabled",
      ],
    }, data.fetch("errors"))

    attributes = FactoryBot.build(:admin_group, {
      :permission_ids => ["admin_manage", "admin_view"],
    }).serializable_hash
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin_group => attributes),
    }))
    assert_response_code(201, response)
  end
end
