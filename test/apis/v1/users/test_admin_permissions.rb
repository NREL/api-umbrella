require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestAdminPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_default_admin_view_permissions
    factory = :api_user
    assert_default_admin_permissions(factory, :required_permissions => ["user_view"], :scopes_irrelevant => true)
  end

  def test_default_admin_manage_permissions
    factory = :api_user
    assert_default_admin_permissions(factory, :required_permissions => ["user_view", "user_manage"], :scopes_irrelevant => true)
  end

  private

  def assert_admin_permitted(factory, admin)
    assert_admin_permitted_index(factory, admin)
    assert_admin_permitted_show(factory, admin)
    permission_ids = admin.groups.map { |group| group.permission_ids }.flatten.uniq
    if admin.superuser? || permission_ids.include?("user_manage")
      assert_admin_permitted_create(factory, admin)
      assert_admin_permitted_update(factory, admin)
    else
      assert_admin_forbidden_create(factory, admin)
      assert_admin_forbidden_update(factory, admin)
    end
    assert_no_destroy(factory, admin)
  end

  def assert_admin_forbidden(factory, admin)
    assert_admin_forbidden_index(factory, admin)
    assert_admin_forbidden_show(factory, admin)
    assert_admin_forbidden_create(factory, admin)
    assert_admin_forbidden_update(factory, admin)
    assert_no_destroy(factory, admin)
  end

  def assert_admin_permitted_index(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    assert_includes(record_ids, record.id)
  end

  def assert_admin_forbidden_index(factory, admin, role_based_error: false)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    refute_includes(record_ids, record.id)
  end

  def assert_admin_permitted_show(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(["user"], data.keys)
  end

  def assert_admin_forbidden_show(factory, admin, role_based_error: false)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_create(factory, admin)
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))

    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    refute_nil(data["user"]["first_name"])
    assert_equal(attributes["first_name"], data["user"]["first_name"])
    assert_equal(1, active_count - initial_count)
  end

  def assert_admin_forbidden_create(factory, admin, role_based_error: false)
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def assert_admin_permitted_update(factory, admin)
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
    attributes["first_name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))

    assert_response_code(200, response)
    record = ApiUser.find(record.id)
    refute_nil(record.first_name)
    assert_equal(attributes["first_name"], record.first_name)
  end

  def assert_admin_forbidden_update(factory, admin, role_based_error: false)
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
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
  end

  def assert_no_destroy(factory, admin)
    record = FactoryBot.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(404, response)
    assert_equal(0, active_count - initial_count)
  end

  def active_count
    ApiUser.count
  end
end
