require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestRolePermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_permits_superuser_assign_any_role
    FactoryBot.create(:google_api_backend)
    FactoryBot.create(:yahoo_api_backend)
    existing_roles = ApiRole.all_ids
    assert_includes(existing_roles, "google-write")
    assert_includes(existing_roles, "yahoo-write")
    refute_includes(existing_roles, "new-write#{unique_test_id}")

    admin = FactoryBot.create(:admin)
    attr_overrides = {
      "roles" => ["google-write", "yahoo-write", "new-write#{unique_test_id}"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_permits_limited_admin_assign_unused_role
    admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["new-role#{unique_test_id}#{rand(999_999)}"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_permits_limited_admin_assign_role_within_scope
    FactoryBot.create(:google_api_backend)
    existing_roles = ApiRole.all_ids
    assert_includes(existing_roles, "google-write")

    admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["google-write"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_forbids_limited_admin_assign_role_outside_scope
    FactoryBot.create(:yahoo_api_backend)
    existing_roles = ApiRole.all_ids
    assert_includes(existing_roles, "yahoo-write")

    admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["yahoo-write"],
    }
    assert_admin_forbidden_create(:api_user, admin, attr_overrides)
    assert_admin_forbidden_update(:api_user, admin, attr_overrides)
  end

  def test_forbids_limited_admin_assign_role_partial_access
    FactoryBot.create(:google_extra_url_match_api_backend)
    existing_roles = ApiRole.all_ids
    assert_includes(existing_roles, "google-extra-write")

    admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["google-extra-write"],
    }
    assert_admin_forbidden_create(:api_user, admin, attr_overrides)
    assert_admin_forbidden_update(:api_user, admin, attr_overrides)
  end

  def test_permits_limited_admin_assign_key_creator_role
    admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["api-umbrella-key-creator"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_forbids_limited_admin_create_new_api_umbrella_roles
    admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :user_view_and_manage_permission)])
    attr_overrides = {
      "roles" => ["api-umbrella#{unique_test_id}#{rand(999_999)}"],
    }
    assert_admin_forbidden_create(:api_user, admin, attr_overrides)
    assert_admin_forbidden_update(:api_user, admin, attr_overrides)
  end

  def test_permits_superuser_create_new_api_umbrella_roles
    admin = FactoryBot.create(:admin)
    attr_overrides = {
      "roles" => ["api-umbrella#{unique_test_id}#{rand(999_999)}"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_forbids_updating_permitted_users_with_unpermitted_values
    FactoryBot.create(:google_api_backend)
    FactoryBot.create(:yahoo_api_backend)
    existing_roles = ApiRole.all_ids
    assert_includes(existing_roles, "google-write")
    assert_includes(existing_roles, "yahoo-write")

    record = FactoryBot.create(:api_user, {
      :roles => ["google-write"],
    })
    admin = FactoryBot.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    attributes["roles"] = ["yahoo-write"]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(403, response)

    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiUser.find(record.id)
    assert_equal(["google-write"], record.roles)
  end

  def test_forbids_updating_unpermitted_users_with_permitted_values
    FactoryBot.create(:google_api_backend)
    FactoryBot.create(:yahoo_api_backend)
    existing_roles = ApiRole.all_ids
    assert_includes(existing_roles, "google-write")
    assert_includes(existing_roles, "yahoo-write")

    record = FactoryBot.create(:api_user, {
      :roles => ["yahoo-write"],
    })
    admin = FactoryBot.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(403, response)

    attributes["roles"] = ["google-write"]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(403, response)

    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiUser.find(record.id)
    assert_equal(["yahoo-write"], record.roles)
  end

  def test_allows_api_umbrella_key_creator_role_allowed_by_itself
    admin = FactoryBot.create(:admin)
    attr_overrides = {
      "roles" => ["api-umbrella-key-creator"],
    }
    assert_admin_permitted_create(:api_user, admin, attr_overrides)
    assert_admin_permitted_update(:api_user, admin, attr_overrides)
  end

  def test_rejects_api_umbrella_key_creator_role_with_other_roles
    admin = FactoryBot.create(:admin)
    attr_overrides = {
      "roles" => ["api-umbrella-key-creator", "foo"],
    }

    attributes = FactoryBot.attributes_for(:api_user).deep_stringify_keys.deep_merge(attr_overrides)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "errors" => [{
        "code" => "INVALID_INPUT",
        "field" => "role_ids",
        "full_message" => "Roles: no other roles can be assigned when the \"api-umbrella-key-creator\" role is present",
        "message" => "no other roles can be assigned when the \"api-umbrella-key-creator\" role is present",
      }],
    }, data)

    user = FactoryBot.create(:api_user)
    attributes = user.serializable_hash.deep_merge(attr_overrides)
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "errors" => [{
        "code" => "INVALID_INPUT",
        "field" => "role_ids",
        "full_message" => "Roles: no other roles can be assigned when the \"api-umbrella-key-creator\" role is present",
        "message" => "no other roles can be assigned when the \"api-umbrella-key-creator\" role is present",
      }],
    }, data)
  end

  private

  def assert_admin_permitted_create(factory, admin, attr_overrides = {})
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys.deep_merge(attr_overrides)
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))

    assert_response_code(201, response)
    assert_equal(1, active_count - initial_count)
    data = MultiJson.load(response.body)
    refute_nil(data["user"]["first_name"])
    assert_equal(attributes["first_name"], data["user"]["first_name"])
    record = ApiUser.find(data["user"]["id"])

    refute_empty(attr_overrides["roles"])
    assert_equal(attr_overrides["roles"].sort, record.roles.sort)
  end

  def assert_admin_forbidden_create(factory, admin, attr_overrides = {})
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys.deep_merge(attr_overrides)
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))

    assert_response_code(403, response)
    assert_equal(0, active_count - initial_count)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_update(factory, admin, attr_overrides = {})
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash.deep_merge(attr_overrides)
    attributes["first_name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))

    assert_response_code(200, response)
    record = ApiUser.find(record.id)
    refute_nil(record.first_name)
    assert_equal(attributes["first_name"], record.first_name)

    refute_empty(attr_overrides["roles"])
    assert_equal(attr_overrides["roles"].sort, record.roles.sort)
  end

  def assert_admin_forbidden_update(factory, admin, attr_overrides = {})
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash.deep_merge(attr_overrides)
    attributes["first_name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiUser.find(record.id)
    refute_nil(record.first_name)
    refute_equal(attributes["first_name"], record.first_name)

    refute_empty(attr_overrides["roles"])
    refute_equal(attr_overrides["roles"], record.roles)
  end

  def active_count
    ApiUser.count
  end
end
