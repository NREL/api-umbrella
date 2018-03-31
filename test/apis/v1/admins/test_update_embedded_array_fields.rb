require_relative "../../../test_helper"

class Test::Apis::V1::Admins::TestUpdateEmbeddedArrayFields < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_adds
    admin_group1 = FactoryBot.create(:admin_group)
    admin = FactoryBot.create(:admin)
    assert_equal([], admin.group_ids)

    attributes = admin.serializable_hash
    attributes["group_ids"] = [admin_group1.id]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(200, response)

    admin.reload
    assert_equal([admin_group1.id], admin.group_ids)
  end

  def test_updates
    admin_group1 = FactoryBot.create(:admin_group)
    admin_group2 = FactoryBot.create(:admin_group)
    admin = FactoryBot.create(:admin, {
      :group_ids => [admin_group1.id],
    })
    assert_equal([admin_group1.id], admin.group_ids)

    attributes = admin.serializable_hash
    attributes["group_ids"] = [admin_group2.id]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(200, response)

    admin.reload
    assert_equal([admin_group2.id], admin.group_ids)
  end

  def test_removes_single_value
    admin_group1 = FactoryBot.create(:admin_group)
    admin_group2 = FactoryBot.create(:admin_group)
    admin = FactoryBot.create(:admin, {
      :group_ids => [admin_group1.id, admin_group2.id],
    })
    assert_equal([admin_group1.id, admin_group2.id].sort, admin.group_ids.sort)

    attributes = admin.serializable_hash
    attributes["group_ids"].shift
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(200, response)

    admin.reload
    assert_equal([admin_group2.id], admin.group_ids)
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
      admin_group1 = FactoryBot.create(:admin_group)
      admin = FactoryBot.create(:admin, {
        :group_ids => [admin_group1.id],
      })
      assert_equal([admin_group1.id], admin.group_ids)

      attributes = admin.serializable_hash
      attributes["group_ids"] = empty_value
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:admin => attributes),
      }))
      assert_response_code(200, response)

      admin.reload
      assert_equal([], admin.group_ids)
    end
  end

  def test_keeps_not_present_keys
    admin_group1 = FactoryBot.create(:admin_group)
    admin = FactoryBot.create(:admin, {
      :group_ids => [admin_group1.id],
    })
    refute_equal("Updated", admin.name)
    assert_equal([admin_group1.id], admin.group_ids)

    attributes = admin.serializable_hash
    attributes["name"] = "Updated"
    attributes.delete("group_ids")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(200, response)

    admin.reload
    assert_equal("Updated", admin.name)
    assert_equal([admin_group1.id], admin.group_ids)
  end
end
