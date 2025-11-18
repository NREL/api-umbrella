require_relative "../../../test_helper"

class Test::Apis::V1::AdminGroups::TestUpdateEmbeddedArrayFields < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_adds
    api_scope1 = FactoryBot.create(:api_scope)
    api_scope2 = FactoryBot.create(:api_scope)
    admin_group = FactoryBot.create(:admin_group, {
      :api_scope_ids => [api_scope1.id],
      :permission_ids => ["analytics"],
    })
    assert_equal([api_scope1.id], admin_group.api_scope_ids)
    assert_equal(["analytics"], admin_group.permission_ids)

    attributes = admin_group.serializable_hash
    attributes["api_scope_ids"] = [api_scope1.id, api_scope2.id]
    attributes["permission_ids"] = ["analytics", "user_view"]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{admin_group.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin_group => attributes),
    }))
    assert_response_code(204, response)

    admin_group.reload
    assert_equal([api_scope1.id, api_scope2.id].sort, admin_group.api_scope_ids.sort)
    assert_equal(["analytics", "user_view"].sort, admin_group.permission_ids.sort)
  end

  def test_updates
    api_scope1 = FactoryBot.create(:api_scope)
    api_scope2 = FactoryBot.create(:api_scope)
    admin_group = FactoryBot.create(:admin_group, {
      :api_scope_ids => [api_scope1.id],
      :permission_ids => ["analytics"],
    })
    assert_equal([api_scope1.id], admin_group.api_scope_ids)
    assert_equal(["analytics"], admin_group.permission_ids)

    attributes = admin_group.serializable_hash
    attributes["api_scope_ids"] = [api_scope2.id]
    attributes["permission_ids"] = ["admin_view"]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{admin_group.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin_group => attributes),
    }))
    assert_response_code(204, response)

    admin_group.reload
    assert_equal([api_scope2.id], admin_group.api_scope_ids)
    assert_equal(["admin_view"], admin_group.permission_ids)
  end

  def test_removes_single_value
    api_scope1 = FactoryBot.create(:api_scope)
    api_scope2 = FactoryBot.create(:api_scope)
    admin_group = FactoryBot.create(:admin_group, {
      :api_scope_ids => [api_scope1.id, api_scope2.id],
      :permission_ids => ["analytics", "user_view"],
    })
    assert_equal([api_scope1.id, api_scope2.id].sort, admin_group.api_scope_ids.sort)
    assert_equal(["analytics", "user_view"].sort, admin_group.permission_ids.sort)

    attributes = admin_group.serializable_hash
    attributes["api_scope_ids"] -= [api_scope1.id]
    attributes["permission_ids"] -= ["analytics"]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{admin_group.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin_group => attributes),
    }))
    assert_response_code(204, response)

    admin_group.reload
    assert_equal([api_scope2.id], admin_group.api_scope_ids)
    assert_equal(["user_view"], admin_group.permission_ids)
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
      api_scope1 = FactoryBot.create(:api_scope)
      admin_group = FactoryBot.create(:admin_group, {
        :api_scope_ids => [api_scope1.id],
        :permission_ids => ["analytics"],
      })
      assert_equal([api_scope1.id], admin_group.api_scope_ids)
      assert_equal(["analytics"], admin_group.permission_ids)

      attributes = admin_group.serializable_hash
      attributes["api_scope_ids"] = empty_value
      attributes["permission_ids"] = empty_value
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{admin_group.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:admin_group => attributes),
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => {
          "api_scopes" => ["can't be blank"],
          "permissions" => ["can't be blank"],
        },
      }, data)

      admin_group.reload
      assert_equal([api_scope1.id], admin_group.api_scope_ids)
      assert_equal(["analytics"], admin_group.permission_ids)
    end
  end

  def test_keeps_not_present_keys
    api_scope1 = FactoryBot.create(:api_scope)
    admin_group = FactoryBot.create(:admin_group, {
      :api_scope_ids => [api_scope1.id],
      :permission_ids => ["analytics"],
    })
    refute_equal("Updated", admin_group.name)
    assert_equal([api_scope1.id], admin_group.api_scope_ids)
    assert_equal(["analytics"], admin_group.permission_ids)

    attributes = admin_group.serializable_hash
    attributes["name"] = "Updated"
    attributes.delete("api_scope_ids")
    attributes.delete("permission_ids")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admin_groups/#{admin_group.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin_group => attributes),
    }))
    assert_response_code(204, response)

    admin_group.reload
    assert_equal("Updated", admin_group.name)
    assert_equal([api_scope1.id], admin_group.api_scope_ids)
    assert_equal(["analytics"], admin_group.permission_ids)
  end
end
