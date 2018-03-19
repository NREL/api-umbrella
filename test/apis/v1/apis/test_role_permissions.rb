require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestRolePermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Api.delete_all
  end

  def test_permits_superuser_assign_any_role
    FactoryGirl.create(:google_api)
    FactoryGirl.create(:yahoo_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "google-write")
    assert_includes(existing_roles, "yahoo-write")
    refute_includes(existing_roles, "new-write#{unique_test_id}")

    admin = FactoryGirl.create(:admin)
    attr_overrides = {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "test-write",
          "google-write",
          "yahoo-write",
          "new-write#{unique_test_id}",
          "new-write#{unique_test_id}#{rand(999_999)}",
        ],
      }),
      :sub_settings => [
        FactoryGirl.attributes_for(:api_sub_setting, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "test-write",
              "google-write",
              "yahoo-write",
              "new-write#{unique_test_id}",
              "new-write#{unique_test_id}#{rand(999_999)}",
            ],
          }),
        }),
      ],
    }.deep_stringify_keys
    assert_admin_permitted_create(:api, admin, attr_overrides)
    assert_admin_permitted_update(:api, admin, attr_overrides)
  end

  def test_permits_limited_admin_assign_unused_role
    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_permission)])
    attr_overrides = {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "new-settings-role#{unique_test_id}#{rand(999_999)}",
        ],
      }),
      :sub_settings => [
        FactoryGirl.attributes_for(:api_sub_setting, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "new-sub-settings-role#{unique_test_id}#{rand(999_999)}",
            ],
          }),
        }),
      ],
    }.deep_stringify_keys
    assert_admin_permitted_create(:google_api, admin, attr_overrides)
    assert_admin_permitted_update(:google_api, admin, attr_overrides)
  end

  def test_permits_limited_admin_assign_role_within_scope
    FactoryGirl.create(:google_api, {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "google2-write",
        ],
      }),
    })
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "google-write")
    assert_includes(existing_roles, "google2-write")

    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_permission)])
    attr_overrides = {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "google2-write",
        ],
      }),
      :sub_settings => [
        FactoryGirl.attributes_for(:api_sub_setting, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "google2-write",
            ],
          }),
        }),
      ],
    }.deep_stringify_keys
    assert_admin_permitted_create(:google_api, admin, attr_overrides)
    assert_admin_permitted_update(:google_api, admin, attr_overrides)
  end

  def test_forbids_limited_admin_assign_role_outside_scope
    FactoryGirl.create(:yahoo_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "yahoo-write")

    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_permission)])
    attr_overrides = {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "yahoo-write",
        ],
      }),
    }.deep_stringify_keys
    assert_admin_forbidden_create(:google_api, admin, attr_overrides)
    assert_admin_forbidden_update(:google_api, admin, attr_overrides)
  end

  def test_forbids_limited_admin_assign_sub_setting_role_outside_scope
    FactoryGirl.create(:yahoo_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "yahoo-write")

    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_permission)])
    attr_overrides = {
      :sub_settings => [
        FactoryGirl.attributes_for(:api_sub_setting, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "yahoo-write",
            ],
          }),
        }),
      ],
    }.deep_stringify_keys
    assert_admin_forbidden_create(:google_api, admin, attr_overrides)
    assert_admin_forbidden_update(:google_api, admin, attr_overrides)
  end

  def test_forbids_limited_admin_assign_role_partial_access
    FactoryGirl.create(:google_extra_url_match_api)
    existing_roles = ApiUserRole.all
    assert_includes(existing_roles, "google-extra-write")
    assert_includes(existing_roles, "google-write")

    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_permission)])
    attr_overrides = {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "google-extra-write",
        ],
      }),
    }.deep_stringify_keys
    assert_admin_forbidden_create(:google_api, admin, attr_overrides)
    assert_admin_forbidden_update(:google_api, admin, attr_overrides)
  end

  def test_forbids_limited_admin_create_new_api_umbrella_roles
    admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_permission)])
    attr_overrides = {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "api-umbrella#{rand(999_999)}",
        ],
      }),
    }.deep_stringify_keys
    assert_admin_forbidden_create(:google_api, admin, attr_overrides)
    assert_admin_forbidden_update(:google_api, admin, attr_overrides)
  end

  def test_permits_superuser_create_new_api_umbrella_roles
    admin = FactoryGirl.create(:admin)
    attr_overrides = {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "api-umbrella#{unique_test_id}#{rand(999_999)}",
        ],
      }),
    }.deep_stringify_keys
    assert_admin_permitted_create(:google_api, admin, attr_overrides)
    assert_admin_permitted_update(:google_api, admin, attr_overrides)
  end

  private

  def assert_admin_permitted_create(factory, admin, attr_overrides = {})
    attributes = FactoryGirl.attributes_for(factory).deep_stringify_keys.deep_merge(attr_overrides)
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))

    assert_response_code(201, response)
    assert_equal(1, active_count - initial_count)
    data = MultiJson.load(response.body)
    refute_nil(data["api"]["name"])
    assert_equal(attributes["name"], data["api"]["name"])
    record = Api.find(data["api"]["id"])

    refute_empty(attr_overrides["settings"]["required_roles"])
    assert_equal(attr_overrides["settings"]["required_roles"], record.settings.required_roles)
    if(attr_overrides["sub_settings"])
      refute_empty(attr_overrides["sub_settings"][0]["settings"]["required_roles"])
      assert_equal(attr_overrides["sub_settings"][0]["settings"]["required_roles"], record.sub_settings[0].settings.required_roles)
    end
  end

  def assert_admin_forbidden_create(factory, admin, attr_overrides = {})
    attributes = FactoryGirl.attributes_for(factory).deep_stringify_keys.deep_merge(attr_overrides)
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))

    assert_response_code(403, response)
    assert_equal(0, active_count - initial_count)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_update(factory, admin, attr_overrides = {})
    record = FactoryGirl.create(factory)

    attributes = record.serializable_hash.deep_merge(attr_overrides)
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))

    assert_response_code(204, response)
    record = Api.find(record.id)
    refute_nil(record.name)
    assert_equal(attributes["name"], record.name)

    refute_empty(attr_overrides["settings"]["required_roles"])
    assert_equal(attr_overrides["settings"]["required_roles"], record.settings.required_roles)
    if(attr_overrides["sub_settings"])
      refute_empty(attr_overrides["sub_settings"][0]["settings"]["required_roles"])
      assert_equal(attr_overrides["sub_settings"][0]["settings"]["required_roles"], record.sub_settings[0].settings.required_roles)
    end
  end

  def assert_admin_forbidden_update(factory, admin, attr_overrides = {})
    record = FactoryGirl.create(factory)

    attributes = record.serializable_hash.deep_merge(attr_overrides)
    attributes["name"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = Api.find(record.id)
    refute_nil(record.name)
    refute_equal(attributes["name"], record.name)
    attr_overrides.each_key do |key|
      refute_equal(attributes[key], record[key])
    end
  end

  def active_count
    Api.where(:deleted_at => nil).count
  end
end
