require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestAdminPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_default_permissions_single_scope
    factory = :google_api_backend
    assert_default_admin_permissions(factory, :required_permissions => ["backend_manage"])
  end

  def test_multi_prefix_permitted_as_superuser
    factory = :google_extra_url_match_api_backend
    admin = FactoryBot.create(:admin)
    assert_admin_permitted(factory, admin)
  end

  def test_multi_prefix_permitted_as_multi_prefix_admin
    factory = :google_extra_url_match_api_backend
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:extra_api_scope)),
      ]),
    ])
    assert_admin_permitted(factory, admin)
  end

  def test_multi_prefix_forbidden_as_single_prefix_admin
    factory = :google_extra_url_match_api_backend

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, admin)

    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryBot.build(:extra_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_invalid_no_prefix_permitted_as_superuser
    factory = :empty_url_matches_api_backend
    admin = FactoryBot.create(:admin)
    assert_admin_permitted(factory, admin, :invalid_record => true)
  end

  def test_invalid_no_prefix_forbidden_as_full_host_admin
    factory = :empty_url_matches_api_backend
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:localhost_root_admin_group),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_invalid_no_prefix_forbidden_as_prefix_admin
    factory = :empty_url_matches_api_backend
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_forbids_updating_permitted_apis_with_unpermitted_values
    record = FactoryBot.create(:google_api_backend)
    admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_manage_permission)])

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    attributes["name"] += rand(999_999).to_s
    attributes["url_matches"] << FactoryBot.attributes_for(:api_backend_url_match, :frontend_prefix => "/foo", :backend_prefix => "/")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiBackend.find(record.id)
    refute_equal(attributes["name"], record.name)
    assert_equal(1, record.url_matches.length)
  end

  def test_forbids_updating_unpermitted_apis_with_permitted_values
    record = FactoryBot.create(:api_backend, :url_matches => [
      FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/yahoo", :backend_prefix => "/"),
    ])
    admin = FactoryBot.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(403, response)

    attributes["url_matches"][0]["frontend_prefix"] = "/google"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiBackend.find(record.id)
    assert_equal("/yahoo", record.url_matches[0].frontend_prefix)
  end

  1000.times do |i|
    # def test_returns_list_of_permitted_scopes_in_forbidden_error
    define_method("test_returns_list_of_permitted_scopes_in_forbidden_error#{i}") do
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:admin_group, :api_scopes => [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:api_scope, :path_prefix => "/a")),
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:api_scope, :path_prefix => "/c")),
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:api_scope, :path_prefix => "/b")),
        ]),
      ])

      attributes = FactoryBot.attributes_for(:google_api_backend)
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(403, response)
      data = MultiJson.load(response.body)
      assert_equal([
        {
          "code" => "FORBIDDEN",
          "message" => "You are not authorized to perform this action. You are only authorized to perform actions for APIs in the following areas:\n\n- localhost/a\n- localhost/b\n- localhost/c\n\nContact your API Umbrella administrator if you need access to new APIs.",
        },
      ], data["errors"])
    end
  end

  private

  def assert_admin_permitted(factory, admin, options = {})
    assert_admin_permitted_index(factory, admin)
    assert_admin_permitted_show(factory, admin)
    assert_admin_permitted_create(factory, admin, options)
    assert_admin_permitted_update(factory, admin, options)
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
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    assert_includes(record_ids, record.id)
  end

  def assert_admin_forbidden_index(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    refute_includes(record_ids, record.id)
  end

  def assert_admin_permitted_show(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(["api"], data.keys)
  end

  def assert_admin_forbidden_show(factory, admin)
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_create(factory, admin, options = {})
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))

    if(options[:invalid_record])
      assert_response_code(422, response)
      assert_equal(0, active_count - initial_count)
    else
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      refute_nil(data["api"]["name"])
      assert_equal(attributes["name"], data["api"]["name"])
      assert_equal(1, active_count - initial_count)
    end
  end

  def assert_admin_forbidden_create(factory, admin)
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def assert_admin_permitted_update(factory, admin, options = {})
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))

    if(options[:invalid_record])
      assert_response_code(422, response)
    else
      assert_response_code(204, response)
      record = ApiBackend.find(record.id)
      refute_nil(record.name)
      assert_equal(attributes["name"], record.name)
    end
  end

  def assert_admin_forbidden_update(factory, admin)
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = ApiBackend.find(record.id)
    refute_nil(record.name)
    refute_equal(attributes["name"], record.name)
  end

  def assert_admin_permitted_destroy(factory, admin)
    record = FactoryBot.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(204, response)
    assert_equal(-1, active_count - initial_count)
  end

  def assert_admin_forbidden_destroy(factory, admin)
    record = FactoryBot.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def active_count
    ApiBackend.count
  end
end
