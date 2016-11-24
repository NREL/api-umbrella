require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestRolePermissions < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    ApiUser.where(:registration_source.ne => "seed").delete_all
    Admin.delete_all
    AdminGroup.delete_all
    Api.delete_all
    ApiScope.delete_all
  end

  def test_permits_superuser_assign_any_role
    FactoryGirl.create(:google_api)
    FactoryGirl.create(:yahoo_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "google-write")
    assert_includes(existing_roles, "yahoo-write")
    refute_includes(existing_roles, "new-write")

    admin = FactoryGirl.create(:admin)
    attr_overrides = {
      "roles" => ["google-write", "yahoo-write", "new-write"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_permits_limited_admin_assign_unused_role
    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["new-role#{rand(999_999)}"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_permits_limited_admin_assign_role_within_scope
    FactoryGirl.create(:google_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "google-write")

    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["google-write"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_forbids_limited_admin_assign_role_outside_scope
    FactoryGirl.create(:yahoo_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "yahoo-write")

    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["yahoo-write"],
    }
    assert_admin_forbidden_create(:api_user, admin, attr_overrides)
    assert_admin_forbidden_update(:api_user, admin, attr_overrides)
  end

  def test_forbids_limited_admin_assign_role_partial_access
    FactoryGirl.create(:google_extra_url_match_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "google-extra-write")

    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["google-extra-write"],
    }
    assert_admin_forbidden_create(:api_user, admin, attr_overrides)
    assert_admin_forbidden_update(:api_user, admin, attr_overrides)
  end

  def test_permits_limited_admin_assign_key_creator_role
    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["api-umbrella-key-creator"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_forbids_limited_admin_create_new_api_umbrella_roles
    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["api-umbrella#{rand(999_999)}"],
    }
    assert_admin_forbidden_create(:api_user, admin, attr_overrides)
    assert_admin_forbidden_update(:api_user, admin, attr_overrides)
  end

  def test_permits_superuser_create_new_api_umbrella_roles
    admin = FactoryGirl.create(:admin)
    attr_overrides = {
      "roles" => ["api-umbrella#{rand(999_999)}"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_forbids_updating_permitted_users_with_unpermitted_values
    FactoryGirl.create(:google_api)
    FactoryGirl.create(:yahoo_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "google-write")
    assert_includes(existing_roles, "yahoo-write")

    record = FactoryGirl.create(:api_user, {
      :roles => ["google-write"],
    })
    admin = FactoryGirl.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_equal(200, response.code, response.body)

    attributes["roles"] = ["yahoo-write"]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_equal(403, response.code, response.body)

    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiUser.find(record.id)
    assert_equal(["google-write"], record.roles)
  end

  def test_forbids_updating_unpermitted_users_with_permitted_values
    FactoryGirl.create(:google_api)
    FactoryGirl.create(:yahoo_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "google-write")
    assert_includes(existing_roles, "yahoo-write")

    record = FactoryGirl.create(:api_user, {
      :roles => ["yahoo-write"],
    })
    admin = FactoryGirl.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_equal(403, response.code, response.body)

    attributes["roles"] = ["google-write"]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_equal(403, response.code, response.body)

    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiUser.find(record.id)
    assert_equal(["yahoo-write"], record.roles)
  end

  private

  def assert_admin_permitted_create(factory, admin, attr_overrides = {})
    attributes = FactoryGirl.attributes_for(factory).deep_stringify_keys.deep_merge(attr_overrides)
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))

    assert_equal(201, response.code, response.body)
    assert_equal(1, active_count - initial_count)
    data = MultiJson.load(response.body)
    refute_equal(nil, data["user"]["first_name"])
    assert_equal(attributes["first_name"], data["user"]["first_name"])
    record = ApiUser.find(data["user"]["id"])

    refute_empty(attr_overrides["roles"])
    assert_equal(attr_overrides["roles"], record.roles)
  end

  def assert_admin_forbidden_create(factory, admin, attr_overrides = {})
    attributes = FactoryGirl.attributes_for(factory).deep_stringify_keys.deep_merge(attr_overrides)
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))

    assert_equal(403, response.code, response.body)
    assert_equal(0, active_count - initial_count)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_update(factory, admin, attr_overrides = {})
    record = FactoryGirl.create(factory)

    attributes = record.serializable_hash.deep_merge(attr_overrides)
    attributes["first_name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))

    assert_equal(200, response.code, response.body)
    record = ApiUser.find(record.id)
    refute_equal(nil, record.first_name)
    assert_equal(attributes["first_name"], record.first_name)

    refute_empty(attr_overrides["roles"])
    assert_equal(attr_overrides["roles"], record.roles)
  end

  def assert_admin_forbidden_update(factory, admin, attr_overrides = {})
    record = FactoryGirl.create(factory)

    attributes = record.serializable_hash.deep_merge(attr_overrides)
    attributes["first_name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))

    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiUser.find(record.id)
    refute_equal(nil, record.first_name)
    refute_equal(attributes["first_name"], record.first_name)

    refute_empty(attr_overrides["roles"])
    refute_equal(attr_overrides["roles"], record.roles)
  end

  def active_count
    ApiUser.where(:deleted_at => nil).count
  end
end
