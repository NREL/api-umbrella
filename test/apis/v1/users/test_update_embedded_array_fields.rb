require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestUpdateEmbeddedArrayFields < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_adds
    user = FactoryBot.create(:api_user)
    assert_equal([], user.roles)
    assert_nil(user.settings)

    attributes = user.serializable_hash
    attributes["roles"] = ["test-role1", "test-role2"]
    attributes["settings"] ||= {}
    attributes["settings"]["allowed_ips"] = ["127.0.0.1", "127.0.0.2"]
    attributes["settings"]["allowed_referers"] = ["http://google.com/", "http://yahoo.com/"]
    attributes["settings"]["rate_limit_mode"] = "custom"
    attributes["settings"]["rate_limits"] = [
      FactoryBot.attributes_for(:rate_limit, :duration => 5000, :limit_to => 10),
      FactoryBot.attributes_for(:rate_limit, :duration => 10000, :limit_to => 20),
    ]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    user.reload
    assert_equal(["test-role1", "test-role2"].sort, user.roles.sort)
    assert_equal([IPAddr.new("127.0.0.1"), IPAddr.new("127.0.0.2")].sort, user.settings.allowed_ips.sort)
    assert_equal(["http://google.com/", "http://yahoo.com/"].sort, user.settings.allowed_referers.sort)
    assert_equal(2, user.settings.rate_limits.length)
    assert_equal(10, user.settings.rate_limits[0].limit_to)
    assert_equal(20, user.settings.rate_limits[1].limit_to)
  end

  def test_updates
    user = FactoryBot.create(:api_user, {
      :roles => ["test-role1"],
      :settings => FactoryBot.build(:api_user_settings, {
        :allowed_ips => ["127.0.0.1"],
        :allowed_referers => ["http://google.com/"],
        :rate_limit_mode => "custom",
        :rate_limits => [
          FactoryBot.build(:rate_limit, :duration => 5000, :limit_to => 10),
          FactoryBot.build(:rate_limit, :duration => 10000, :limit_to => 20),
        ],
      }),
    })
    assert_equal(["test-role1"], user.roles)
    assert_equal([IPAddr.new("127.0.0.1")], user.settings.allowed_ips)
    assert_equal(["http://google.com/"], user.settings.allowed_referers)
    assert_equal(2, user.settings.rate_limits.length)
    assert_equal(10, user.settings.rate_limits[0].limit_to)
    assert_equal(20, user.settings.rate_limits[1].limit_to)

    attributes = user.serializable_hash
    attributes["roles"] = ["test-role5", "test-role4"]
    attributes["settings"]["allowed_ips"] = ["127.0.0.5", "127.0.0.4"]
    attributes["settings"]["allowed_referers"] = ["https://example.com", "https://bing.com/foo"]
    attributes["settings"]["rate_limits"][0]["limit"] = 50
    attributes["settings"]["rate_limits"][1]["limit"] = 75
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    user.reload
    assert_equal(["test-role5", "test-role4"].sort, user.roles.sort)
    assert_equal([IPAddr.new("127.0.0.5"), IPAddr.new("127.0.0.4")].sort, user.settings.allowed_ips.sort)
    assert_equal(["https://example.com", "https://bing.com/foo"], user.settings.allowed_referers)
    assert_equal(2, user.settings.rate_limits.length)
    assert_equal(attributes["settings"]["rate_limits"][0]["id"], user.settings.rate_limits[0].id)
    assert_equal(5000, user.settings.rate_limits[0].duration)
    assert_equal(50, user.settings.rate_limits[0].limit_to)
    assert_equal(attributes["settings"]["rate_limits"][1]["id"], user.settings.rate_limits[1].id)
    assert_equal(10000, user.settings.rate_limits[1].duration)
    assert_equal(75, user.settings.rate_limits[1].limit_to)
  end

  def test_removes_single_value
    user = FactoryBot.create(:api_user, {
      :roles => ["test-role1", "test-role2"],
      :settings => FactoryBot.build(:api_user_settings, {
        :allowed_ips => ["127.0.0.1", "127.0.0.2"],
        :allowed_referers => ["http://google.com/", "http://yahoo.com/"],
        :rate_limit_mode => "custom",
        :rate_limits => [
          FactoryBot.build(:rate_limit, :duration => 5000, :limit_to => 10),
          FactoryBot.build(:rate_limit, :duration => 10000, :limit_to => 20),
        ],
      }),
    })
    assert_equal(["test-role1", "test-role2"].sort, user.roles.sort)
    assert_equal([IPAddr.new("127.0.0.1"), IPAddr.new("127.0.0.2")].sort, user.settings.allowed_ips.sort)
    assert_equal(["http://google.com/", "http://yahoo.com/"].sort, user.settings.allowed_referers.sort)
    assert_equal(2, user.settings.rate_limits.length)
    assert_equal(10, user.settings.rate_limits[0].limit_to)
    assert_equal(20, user.settings.rate_limits[1].limit_to)

    attributes = user.serializable_hash
    attributes["roles"] -= ["test-role1"]
    attributes["settings"]["allowed_ips"] -= ["127.0.0.1"]
    attributes["settings"]["allowed_referers"] -= ["http://google.com/"]
    attributes["settings"]["rate_limits"].shift
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    user.reload
    assert_equal(["test-role2"], user.roles)
    assert_equal([IPAddr.new("127.0.0.2")], user.settings.allowed_ips)
    assert_equal(["http://yahoo.com/"], user.settings.allowed_referers)
    assert_equal(1, user.settings.rate_limits.length)
    assert_equal(attributes["settings"]["rate_limits"][0]["id"], user.settings.rate_limits[0].id)
    assert_equal(20, user.settings.rate_limits[0].limit_to)
  end

  [nil, []].each do |empty_value|
    empty_method_name =
      case(empty_value)
      when nil
        "null"
      when []
        "empty_array"
      end

    define_method("test_removes_#{empty_method_name}") do
      user = FactoryBot.create(:api_user, {
        :roles => ["test-role1"],
        :settings => FactoryBot.build(:api_user_settings, {
          :allowed_ips => ["127.0.0.1"],
          :allowed_referers => ["http://google.com/"],
          :rate_limit_mode => "custom",
          :rate_limits => [
            FactoryBot.build(:rate_limit, :duration => 5000, :limit_to => 10),
            FactoryBot.build(:rate_limit, :duration => 10000, :limit_to => 20),
          ],
        }),
      })
      assert_equal(["test-role1"], user.roles)
      assert_equal([IPAddr.new("127.0.0.1")], user.settings.allowed_ips)
      assert_equal(["http://google.com/"], user.settings.allowed_referers)
      assert_equal(10, user.settings.rate_limits[0].limit_to)
      assert_equal(20, user.settings.rate_limits[1].limit_to)

      attributes = user.serializable_hash
      attributes["roles"] = empty_value
      attributes["settings"]["allowed_ips"] = empty_value
      attributes["settings"]["allowed_referers"] = empty_value
      attributes["settings"]["rate_limits"] = empty_value

      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:user => attributes),
      }))
      assert_response_code(200, response)

      user.reload
      assert_equal([], user.roles)
      if(empty_value == [])
        assert_equal([], user.settings.allowed_ips)
        assert_equal([], user.settings.allowed_referers)
      else
        assert_nil(user.settings.allowed_ips)
        assert_nil(user.settings.allowed_referers)
      end
      assert_equal([], user.settings.rate_limits)
    end
  end

  def test_keeps_not_present_keys
    user = FactoryBot.create(:api_user, {
      :roles => ["test-role1"],
      :settings => FactoryBot.build(:api_user_settings, {
        :allowed_ips => ["127.0.0.1"],
        :allowed_referers => ["http://google.com/"],
        :rate_limit_mode => "custom",
        :rate_limits => [
          FactoryBot.build(:rate_limit, :duration => 5000, :limit_to => 10),
          FactoryBot.build(:rate_limit, :duration => 10000, :limit_to => 20),
        ],
      }),
    })
    refute_equal("Updated", user.use_description)
    assert_equal(["test-role1"], user.roles)
    assert_equal([IPAddr.new("127.0.0.1")], user.settings.allowed_ips)
    assert_equal(["http://google.com/"], user.settings.allowed_referers)
    assert_equal(10, user.settings.rate_limits[0].limit_to)
    assert_equal(20, user.settings.rate_limits[1].limit_to)

    attributes = user.serializable_hash
    attributes["use_description"] = "Updated"
    attributes.delete("roles")
    attributes["settings"].delete("allowed_ips")
    attributes["settings"].delete("allowed_referers")
    attributes["settings"].delete("rate_limits")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    user.reload
    assert_equal("Updated", user.use_description)
    assert_equal(["test-role1"], user.roles)
    assert_equal([IPAddr.new("127.0.0.1")], user.settings.allowed_ips)
    assert_equal(["http://google.com/"], user.settings.allowed_referers)
    assert_equal(10, user.settings.rate_limits[0].limit_to)
    assert_equal(20, user.settings.rate_limits[1].limit_to)
  end
end
