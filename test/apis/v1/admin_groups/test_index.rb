require_relative "../../../test_helper"

class TestApisV1AdminGroupsIndex < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    AdminGroup.delete_all
  end

  def test_admin_usernames_in_group
    group = FactoryGirl.create(:admin_group)
    admin_in_group = FactoryGirl.create(:limited_admin, :groups => [
      group,
    ])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(1, data["data"].length)
    assert_equal([admin_in_group.username], data["data"][0]["admin_usernames"])
  end

  def test_admin_usernames_in_group_sorted_alpha
    group = FactoryGirl.create(:admin_group)
    admin_in_group1 = FactoryGirl.create(:limited_admin, :username => "b", :groups => [
      group,
    ])
    admin_in_group2 = FactoryGirl.create(:limited_admin, :username => "a", :groups => [
      group,
    ])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(1, data["data"].length)
    assert_equal([admin_in_group2.username, admin_in_group1.username], data["data"][0]["admin_usernames"])
  end

  def test_admin_usernames_empty
    FactoryGirl.create(:admin_group)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(1, data["data"].length)
    assert_equal([], data["data"][0]["admin_usernames"])
  end
end
