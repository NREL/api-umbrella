require_relative "../../../test_helper"

class TestApisV1ApisAdminPermissions < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    Api.delete_all
  end

  def test_default_permissions_single_scope
    factory = :google_api
    assert_default_admin_permissions(factory, :required_permissions => ["backend_manage"])
  end

  def test_multi_prefix_permitted_as_superuser
    factory = :google_extra_url_match_api
    admin = FactoryGirl.create(:admin)
    assert_admin_permitted(factory, admin)
  end

  def test_multi_prefix_permitted_as_multi_prefix_admin
    factory = :google_extra_url_match_api
    admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope)),
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:extra_api_scope)),
      ]),
    ])
    assert_admin_permitted(factory, admin)
  end

  def test_multi_prefix_forbidden_as_single_prefix_admin
    factory = :google_extra_url_match_api

    admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, admin)

    admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:extra_api_scope)),
      ]),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_invalid_no_prefix_permitted_as_superuser
    factory = :empty_url_matches_api
    admin = FactoryGirl.create(:admin)
    assert_admin_permitted(factory, admin, :invalid_record => true)
  end

  def test_invalid_no_prefix_forbidden_as_full_host_admin
    factory = :empty_url_matches_api
    admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:localhost_root_admin_group),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_invalid_no_prefix_forbidden_as_prefix_admin
    factory = :empty_url_matches_api
    admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:google_admin_group),
    ])
    assert_admin_forbidden(factory, admin)
  end

  def test_forbids_updating_permitted_apis_with_unpermitted_values
    record = FactoryGirl.create(:google_api)
    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_permission)])

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))
    assert_equal(204, response.code, response.body)

    attributes["name"] += rand(999_999).to_s
    attributes["url_matches"] << FactoryGirl.attributes_for(:api_url_match, :frontend_prefix => "/foo", :backend_prefix => "/")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))
    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Api.find(record.id)
    refute_equal(attributes["name"], record.name)
    assert_equal(1, record.url_matches.length)
  end

  def test_forbids_updating_unpermitted_apis_with_permitted_values
    record = FactoryGirl.create(:api, :url_matches => [
      FactoryGirl.attributes_for(:api_url_match, :frontend_prefix => "/yahoo", :backend_prefix => "/"),
    ])
    admin = FactoryGirl.create(:google_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))
    assert_equal(403, response.code, response.body)

    attributes["url_matches"][0]["frontend_prefix"] = "/google"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))
    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Api.find(record.id)
    assert_equal("/yahoo", record.url_matches[0].frontend_prefix)
  end

  def test_returns_list_of_permitted_scopes_in_forbidden_error
    admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:api_scope, :path_prefix => "/a")),
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:api_scope, :path_prefix => "/c")),
        ApiScope.find_or_create_by_instance!(FactoryGirl.build(:api_scope, :path_prefix => "/b")),
      ]),
    ])

    attributes = FactoryGirl.attributes_for(:google_api)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))
    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal([
      {
        "code" => "FORBIDDEN",
        "message" => "You are not authorized to perform this action. You are only authorized to perform actions for APIs in the following areas:\n\n- localhost/a\n- localhost/b\n- localhost/c\n\nContact your API Umbrella administrator if you need access to new APIs.",
      },
    ], data["errors"])
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
    record = FactoryGirl.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    assert_includes(record_ids, record.id)
  end

  def assert_admin_forbidden_index(factory, admin)
    record = FactoryGirl.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    refute_includes(record_ids, record.id)
  end

  def assert_admin_permitted_show(factory, admin)
    record = FactoryGirl.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["api"], data.keys)
  end

  def assert_admin_forbidden_show(factory, admin)
    record = FactoryGirl.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_create(factory, admin, options = {})
    attributes = FactoryGirl.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))

    if(options[:invalid_record])
      assert_equal(422, response.code, response.body)
      assert_equal(0, active_count - initial_count)
    else
      assert_equal(201, response.code, response.body)
      data = MultiJson.load(response.body)
      refute_equal(nil, data["api"]["name"])
      assert_equal(attributes["name"], data["api"]["name"])
      assert_equal(1, active_count - initial_count)
    end
  end

  def assert_admin_forbidden_create(factory, admin)
    attributes = FactoryGirl.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))

    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def assert_admin_permitted_update(factory, admin, options = {})
    record = FactoryGirl.create(factory)

    attributes = record.serializable_hash
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))

    if(options[:invalid_record])
      assert_equal(422, response.code, response.body)
    else
      assert_equal(204, response.code, response.body)
      record = Api.find(record.id)
      refute_equal(nil, record.name)
      assert_equal(attributes["name"], record.name)
    end
  end

  def assert_admin_forbidden_update(factory, admin)
    record = FactoryGirl.create(factory)

    attributes = record.serializable_hash
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))

    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Api.find(record.id)
    refute_equal(nil, record.name)
    refute_equal(attributes["name"], record.name)
  end

  def assert_admin_permitted_destroy(factory, admin)
    record = FactoryGirl.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_equal(204, response.code, response.body)
    assert_equal(-1, active_count - initial_count)
  end

  def assert_admin_forbidden_destroy(factory, admin)
    record = FactoryGirl.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_equal(403, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def active_count
    Api.where(:deleted_at => nil).count
  end
end
