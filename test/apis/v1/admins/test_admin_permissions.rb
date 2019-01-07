require_relative "../../../test_helper"

class Test::Apis::V1::Admins::TestAdminPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_default_permissions_single_scope
    factory = :google_admin
    assert_default_admin_permissions(factory, :required_permissions => ["admin_manage"])
  end

  def test_multi_group_multi_scope_permitted_as_superuser
    factory = :google_and_yahoo_multi_group_admin
    admin = FactoryBot.create(:admin)
    assert_admin_permitted(factory, admin)
  end

  def test_multi_group_multi_scope_permitted_as_multi_scope_admin
    factory = :google_and_yahoo_multi_group_admin
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_permitted(factory, admin)
  end

  def test_multi_group_multi_scope_forbidden_as_single_scope_admin
    factory = :google_and_yahoo_multi_group_admin

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, admin)

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_single_group_multi_scope_permitted_as_superuser
    factory = :google_and_yahoo_single_group_admin
    admin = FactoryBot.create(:admin)
    assert_admin_permitted(factory, admin)
  end

  def test_single_group_multi_scope_permitted_as_multi_scope_admin
    factory = :google_and_yahoo_single_group_admin
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_permitted(factory, admin)
  end

  def test_single_group_multi_scope_forbidden_as_single_scope_admin
    factory = :google_and_yahoo_single_group_admin

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, admin)

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_superuser_as_superuser
    factory = :admin
    admin = FactoryBot.create(:admin)
    assert_admin_permitted(factory, admin)
  end

  def test_superuser_as_full_host_admin
    factory = :admin
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:localhost_root_admin_group),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_superuser_as_prefix_admin
    factory = :admin
    admin = FactoryBot.create(:google_admin)
    assert_admin_forbidden(factory, admin)
  end

  def test_forbids_updating_permitted_admins_with_unpermitted_values
    google_admin_group = FactoryBot.create(:google_admin_group)
    yahoo_admin_group = FactoryBot.create(:yahoo_admin_group)
    record = FactoryBot.create(:limited_admin, :groups => [google_admin_group])
    admin = FactoryBot.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(200, response)

    attributes["group_ids"] = [yahoo_admin_group.id]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", @@http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Admin.find(record.id)
    assert_equal([google_admin_group.id], record.group_ids)
  end

  def test_forbids_updating_unpermitted_admins_with_permitted_values
    google_admin_group = FactoryBot.create(:google_admin_group)
    yahoo_admin_group = FactoryBot.create(:yahoo_admin_group)
    record = FactoryBot.create(:limited_admin, :groups => [yahoo_admin_group])
    admin = FactoryBot.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(403, response)

    attributes["group_ids"] = [google_admin_group.id]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Admin.find(record.id)
    assert_equal([yahoo_admin_group.id], record.group_ids)
  end

  def test_forbids_limited_admin_adding_superuser_to_existing_admin
    record = FactoryBot.create(:limited_admin)
    admin = FactoryBot.create(:limited_admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "1"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    record = Admin.find(record.id)
    assert_equal(false, record.superuser)
  end

  def test_forbids_limited_admin_adding_superuser_to_own_account
    record = FactoryBot.create(:limited_admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "1"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(record)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    record = Admin.find(record.id)
    assert_equal(false, record.superuser)
  end

  def test_forbids_limited_admin_removing_superuser_from_existing_admin
    record = FactoryBot.create(:limited_admin, :superuser => true)
    admin = FactoryBot.create(:limited_admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "0"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    record = Admin.find(record.id)
    assert_equal(true, record.superuser)
  end

  def test_permits_superuser_adding_superuser_to_existing_admin
    record = FactoryBot.create(:limited_admin)
    admin = FactoryBot.create(:admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "1"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(200, response)
    record = Admin.find(record.id)
    assert_equal(true, record.superuser)
  end

  def test_permits_superuser_removing_superuser_from_existing_admin
    record = FactoryBot.create(:limited_admin, :superuser => true)
    admin = FactoryBot.create(:admin)

    attributes = record.serializable_hash
    attributes["superuser"] = "0"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(200, response)
    record = Admin.find(record.id)
    assert_equal(false, record.superuser)
  end

  def test_permits_any_admin_to_view_but_not_edit_own_record
    # An admin without the "admin_manage" role.
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :analytics_permission),
    ])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(["admin"], data.keys)

    attributes = admin.serializable_hash
    attributes["username"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  private

  def assert_admin_permitted(factory, admin)
    assert_admin_permitted_index(factory, admin)
    assert_admin_permitted_show(factory, admin)
    assert_admin_permitted_create(factory, admin)
    assert_admin_permitted_update(factory, admin)
    assert_admin_permitted_destroy(factory, admin)
  end

  def assert_admin_forbidden(factory, admin)
    assert_admin_forbidden_index(factory, admin)
    assert_admin_forbidden_show(factory, admin)
    assert_admin_forbidden_create(factory, admin)
    assert_admin_forbidden_update(factory, admin)
    assert_admin_forbidden_destroy(factory, admin)
  end

  def assert_admin_permitted_index(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    assert_includes(record_ids, record.id)
  end

  def assert_admin_forbidden_index(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    refute_includes(record_ids, record.id)
  end

  def assert_admin_permitted_show(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(["admin"], data.keys)
  end

  def assert_admin_forbidden_show(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_create(factory, admin)
    attributes = FactoryBot.build(factory).serializable_hash
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    refute_nil(data["admin"]["username"])
    assert_equal(attributes["username"], data["admin"]["username"])
    assert_equal(1, active_count - initial_count)
  end

  def assert_admin_forbidden_create(factory, admin)
    attributes = FactoryBot.build(factory).serializable_hash
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def assert_admin_permitted_update(factory, admin)
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
    attributes["username"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    refute_nil(data["admin"]["username"])
    assert_equal(attributes["username"], data["admin"]["username"])

    record = Admin.find(record.id)
    refute_nil(record.username)
    assert_equal(attributes["username"], record.username)
  end

  def assert_admin_forbidden_update(factory, admin)
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
    attributes["username"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:admin => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Admin.find(record.id)
    refute_nil(record.username)
    refute_equal(attributes["username"], record.username)
  end

  def assert_admin_permitted_destroy(factory, admin)
    record = FactoryBot.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(204, response)
    assert_equal(-1, active_count - initial_count)
  end

  def assert_admin_forbidden_destroy(factory, admin)
    record = FactoryBot.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/admins/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def active_count
    Admin.count
  end
end
