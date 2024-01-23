require_relative "../../../test_helper"

class Test::Apis::V1::ApiScopes::TestAdminPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_default_admin_view_permissions
    factory = :google_api_scope
    assert_default_admin_permissions(factory, :required_permissions => ["admin_view"])
  end

  def test_default_admin_manage_permissions
    factory = :google_api_scope
    assert_default_admin_permissions(factory, :required_permissions => ["admin_view", "admin_manage"])
  end

  def test_forbids_updating_permitted_scopes_with_unpermitted_values
    record = FactoryBot.create(:google_api_scope)
    admin = FactoryBot.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))
    assert_response_code(204, response)

    attributes["path_prefix"] = "/yahoo/#{rand(999_999)}"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiScope.find(record.id)
    assert_equal("/google", record.path_prefix)
  end

  def test_forbids_updating_unpermitted_scopes_with_permitted_values
    record = FactoryBot.create(:yahoo_api_scope)
    admin = FactoryBot.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))
    assert_response_code(403, response)

    attributes["path_prefix"] = "/google/#{rand(999_999)}"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiScope.find(record.id)
    assert_equal("/yahoo", record.path_prefix)
  end

  private

  def assert_admin_permitted(factory, admin)
    assert_admin_permitted_index(factory, admin)
    assert_admin_permitted_show(factory, admin)
    permission_ids = admin.groups.map { |group| group.permission_ids }.flatten.uniq
    if permission_ids.include?("admin_view") && !permission_ids.include?("admin_manage")
      assert_admin_forbidden_create(factory, admin)
      assert_admin_forbidden_update(factory, admin)
      assert_admin_forbidden_destroy(factory, admin)
    else
      assert_admin_permitted_create(factory, admin)
      assert_admin_permitted_update(factory, admin)
      assert_admin_permitted_destroy(factory, admin)
    end
  end

  def assert_admin_forbidden(factory, admin)
    assert_admin_forbidden_index(factory, admin)
    assert_admin_forbidden_show(factory, admin)
    assert_admin_forbidden_create(factory, admin)
    assert_admin_forbidden_update(factory, admin)
    assert_admin_forbidden_destroy(factory, admin)
  end

  def assert_admin_permitted_index(factory, admin)
    record = ApiScope.find_or_create_by_instance!(FactoryBot.build(factory))
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/api_scopes.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    assert_includes(record_ids, record.id)
  end

  def assert_admin_forbidden_index(factory, admin)
    record = ApiScope.find_or_create_by_instance!(FactoryBot.build(factory))
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/api_scopes.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    refute_includes(record_ids, record.id)
  end

  def assert_admin_permitted_show(factory, admin)
    record = ApiScope.find_or_create_by_instance!(FactoryBot.build(factory))
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(["api_scope"], data.keys)
  end

  def assert_admin_forbidden_show(factory, admin)
    record = ApiScope.find_or_create_by_instance!(FactoryBot.build(factory))
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_create(factory, admin)
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/api_scopes.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))

    # Validation errors may occur on some of the create tests, since we can't
    # create duplicate records with the same hostname and prefix.  This is
    # expected to happen in some of the tests where we have to create a scope
    # for the admin group we're authenticating as prior to this create attempt.
    if(response.code == 422)
      data = MultiJson.load(response.body)
      assert_equal({ "errors" => { "path_prefix" => ["is already taken"] } }, data)

      # Add something extra to the path prefix, since create sub-scopes within
      # an existing prefix should be permitted.
      @path_prefix_increment ||= 0
      @path_prefix_increment += 1
      attributes["path_prefix"] += @path_prefix_increment.to_s
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/api_scopes.json", http_options.deep_merge(admin_token(admin)).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api_scope => attributes),
      }))
    end

    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    refute_nil(data["api_scope"]["name"])
    assert_equal(attributes["name"], data["api_scope"]["name"])
    assert_equal(1, active_count - initial_count)
  end

  def assert_admin_forbidden_create(factory, admin)
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/api_scopes.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def assert_admin_permitted_update(factory, admin)
    record = ApiScope.find_or_create_by_instance!(FactoryBot.build(factory))

    attributes = record.serializable_hash
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))

    assert_response_code(204, response)
    record = ApiScope.find(record.id)
    refute_nil(record.name)
    assert_equal(attributes["name"], record.name)
  end

  def assert_admin_forbidden_update(factory, admin)
    record = ApiScope.find_or_create_by_instance!(FactoryBot.build(factory))

    attributes = record.serializable_hash
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiScope.find(record.id)
    refute_nil(record.name)
    refute_equal(attributes["name"], record.name)
  end

  def assert_admin_permitted_destroy(factory, admin)
    record = ApiScope.find_or_create_by_instance!(FactoryBot.build(factory))
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(204, response)
    assert_equal(-1, active_count - initial_count)
  end

  def assert_admin_forbidden_destroy(factory, admin)
    record = ApiScope.find_or_create_by_instance!(FactoryBot.build(factory))
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def active_count
    ApiScope.count
  end
end
