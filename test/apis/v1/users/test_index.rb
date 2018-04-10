require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    ApiUser.where(:registration_source.ne => "seed").delete_all
  end

  include ApiUmbrellaSharedTests::DataTablesApi

  def test_response_fields
    record = FactoryBot.create(data_tables_factory_name, {
      :created_at => Time.utc(2017, 1, 1),
      :created_by => SecureRandom.uuid,
      :disabled_at => Time.utc(2017, 1, 2),
      :email => "foo@example.com",
      :email_verified => true,
      :first_name => "Foo",
      :last_name => "Bar",
      :registration_ip => "127.0.0.10",
      :registration_origin => "http://example.com",
      :registration_referer => "http://example.com/foo",
      :registration_source => "test",
      :registration_user_agent => "curl",
      :roles => ["role1", "role2"],
      :settings => FactoryBot.attributes_for(:custom_rate_limit_api_setting, {
        :rate_limits => [
          FactoryBot.attributes_for(:api_rate_limit, :duration => 5000, :limit_by => "ip", :limit => 10),
        ],
      }),
      :throttle_by_ip => true,
      :updated_at => Time.utc(2017, 1, 3),
      :updated_by => SecureRandom.uuid,
      :use_description => "Usage",
      :website => "http://foo.example.com",
    })

    response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => record.id },
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_data_tables_root_fields(data)
    assert_equal(1, data.fetch("data").length)

    record_data = data.fetch("data").first
    assert_base_record_fields(record_data)

    assert_equal("2017-01-02T00:00:00Z", record_data.fetch("disabled_at"))
    assert_equal("foo@example.com", record_data.fetch("email"))
    assert_equal(true, record_data.fetch("email_verified"))
    assert_equal("Foo", record_data.fetch("first_name"))
    assert_equal("Bar", record_data.fetch("last_name"))
    assert_equal("127.0.0.10", record_data.fetch("registration_ip"))
    assert_equal("http://example.com", record_data.fetch("registration_origin"))
    assert_equal("http://example.com/foo", record_data.fetch("registration_referer"))
    assert_equal("test", record_data.fetch("registration_source"))
    assert_equal("curl", record_data.fetch("registration_user_agent"))
    assert_equal(["role1", "role2"], record_data.fetch("roles"))
    assert_kind_of(Hash, record_data.fetch("settings"))
    assert_equal([
      "allowed_ips",
      "allowed_referers",
      "anonymous_rate_limit_behavior",
      "api_key_verification_level",
      "api_key_verification_transition_start_at",
      "append_query_string",
      "authenticated_rate_limit_behavior",
      "default_response_headers",
      "disable_api_key",
      "error_data",
      "error_templates",
      "headers",
      "http_basic_auth",
      "id",
      "override_response_headers",
      "pass_api_key_header",
      "pass_api_key_query_param",
      "rate_limit_mode",
      "rate_limits",
      "require_https",
      "require_https_transition_start_at",
      "required_roles",
      "required_roles_override",
    ].sort, record_data.fetch("settings").keys.sort)
    assert_kind_of(Array, record_data.fetch("settings").fetch("rate_limits"))
    assert_equal(1, record_data.fetch("settings").fetch("rate_limits").length)
    assert_kind_of(Hash, record_data.fetch("settings").fetch("rate_limits").first)
    assert_equal([
      "accuracy",
      "distributed",
      "duration",
      "limit",
      "limit_by",
      "response_headers",
      "id",
    ], record_data.fetch("settings").fetch("rate_limits").first.keys)
    assert_equal(true, record_data.fetch("throttle_by_ip"))
    assert_match_iso8601(record_data.fetch("updated_at"))
    assert_equal("2017-01-03T00:00:00Z", record_data.fetch("updated_at"))
    assert_match_uuid(record_data.fetch("updated_by"))
    assert_equal(record.updated_by, record_data.fetch("updated_by"))
    assert_equal("Usage", record_data.fetch("use_description"))
    assert_equal("http://foo.example.com", record_data.fetch("website"))
  end

  def test_empty_response_fields
    record = FactoryBot.create(data_tables_factory_name)

    response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => record.id },
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_data_tables_root_fields(data)
    assert_equal(1, data.fetch("data").length)

    record_data = data.fetch("data").first
    assert_base_record_fields(record_data)

    assert_nil(record_data.fetch("disabled_at"))
    assert_nil(record_data.fetch("email_verified"))
    assert_nil(record_data.fetch("created_by"))
    assert_nil(record_data.fetch("disabled_at"))
    assert_nil(record_data.fetch("email_verified"))
    assert_nil(record_data.fetch("registration_ip"))
    assert_nil(record_data.fetch("registration_origin"))
    assert_nil(record_data.fetch("registration_referer"))
    assert_nil(record_data.fetch("registration_source"))
    assert_nil(record_data.fetch("registration_user_agent"))
    assert_nil(record_data.fetch("roles"))
    assert_nil(record_data.fetch("settings"))
    assert_nil(record_data.fetch("throttle_by_ip"))
    assert_nil(record_data.fetch("updated_by"))
    assert_nil(record_data.fetch("use_description"))
    assert_nil(record_data.fetch("website"))
  end

  def test_includes_api_key_preview_not_full_api_key
    api_user = FactoryBot.create(:api_user)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)

    data = MultiJson.load(response.body)
    user = data["data"].find { |u| u["id"] == api_user.id }
    refute_includes(user.keys, "api_key")
    refute_includes(user.keys, "api_key_hides_at")
    assert_equal("#{api_user.api_key[0, 6]}...", user["api_key_preview"])
  end

  def test_search_first_name
    assert_data_tables_search(:first_name, "FirstNameSearchTest", "irstnamesearcht")
  end

  def test_search_last_name
    assert_data_tables_search(:last_name, "LastNameSearchTest", "astnamesearcht")
  end

  def test_search_email
    assert_data_tables_search(:email, "EmailSearchTest@example.com", "mailsearchtest@exampl")
  end

  def test_search_api_key
    assert_data_tables_search(:api_key, "API_KEY_SEARCH_TEST", "_key_search_tes")
  end

  def test_search_registration_source
    assert_data_tables_search(:registration_source, "RegistrationSourceSearchTest", "egistrationsourcesearchtes")
  end

  def test_search_roles
    assert_data_tables_search(:roles, ["RoleSearchTest1", "RoleSearchTest2", "RoleSearchTest33"], "olesearchtest3")
  end

  def test_order_email
    assert_data_tables_order(:email, ["a@example.com", "b@example.com"])
  end

  def test_order_first_name
    assert_data_tables_order(:first_name, ["A", "B"])
  end

  def test_order_last_name
    assert_data_tables_order(:last_name, ["A", "B"])
  end

  def test_order_use_description
    assert_data_tables_order(:use_description, ["A", "B"])
  end

  def test_order_registration_source
    assert_data_tables_order(:registration_source, ["A", "B"])
  end

  private

  def data_tables_api_url
    "https://127.0.0.1:9081/api-umbrella/v1/users.json"
  end

  def data_tables_factory_name
    :api_user
  end

  def data_tables_record_count
    ApiUser.where(:deleted_at => nil).count
  end

  def assert_base_record_fields(record_data)
    assert_equal([
      "api_key_preview",
      "created_at",
      "created_by",
      "deleted_at",
      "disabled_at",
      "email",
      "email_verified",
      "first_name",
      "id",
      "last_name",
      "registration_ip",
      "registration_origin",
      "registration_referer",
      "registration_source",
      "registration_user_agent",
      "roles",
      "settings",
      "throttle_by_ip",
      "ts",
      "updated_at",
      "updated_by",
      "use_description",
      "version",
      "website",
    ].sort, record_data.keys.sort)
    assert_kind_of(String, record_data.fetch("api_key_preview"))
    assert_equal(9, record_data.fetch("api_key_preview").length)
    assert_match_iso8601(record_data.fetch("created_at"))
    assert_nil(record_data.fetch("deleted_at"))
    assert_kind_of(String, record_data.fetch("email"))
    assert_kind_of(String, record_data.fetch("first_name"))
    assert_match_uuid(record_data.fetch("id"))
    assert_kind_of(String, record_data.fetch("last_name"))
    assert_kind_of(Hash, record_data.fetch("ts"))
    assert_equal(["$timestamp"].sort, record_data.fetch("ts").keys.sort)
    assert_kind_of(Hash, record_data.fetch("ts").fetch("$timestamp"))
    assert_equal(["i", "t"].sort, record_data.fetch("ts").fetch("$timestamp").keys.sort)
    assert_kind_of(Integer, record_data.fetch("ts").fetch("$timestamp").fetch("i"))
    assert_kind_of(Integer, record_data.fetch("ts").fetch("$timestamp").fetch("t"))
    assert_match_iso8601(record_data.fetch("updated_at"))
    assert_kind_of(Integer, record_data.fetch("version"))
  end
end
