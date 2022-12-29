require_relative "../../../test_helper"

class Test::Apis::V1::AdminGroups::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  include ApiUmbrellaSharedTests::DataTablesApi

  def test_admin_usernames_in_group
    group = FactoryBot.create(:admin_group)
    admin_in_group = FactoryBot.create(:limited_admin, :groups => [
      group,
    ])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["data"].length)
    assert_equal([admin_in_group.username], data["data"][0]["admin_usernames"])
  end

  def test_admin_usernames_in_group_sorted_alpha
    group = FactoryBot.create(:admin_group)
    admin_in_group1 = FactoryBot.create(:limited_admin, :username => "b", :groups => [
      group,
    ])
    admin_in_group2 = FactoryBot.create(:limited_admin, :username => "a", :groups => [
      group,
    ])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["data"].length)
    assert_equal([admin_in_group2.username, admin_in_group1.username], data["data"][0]["admin_usernames"])
  end

  def test_admin_usernames_empty
    FactoryBot.create(:admin_group)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["data"].length)
    assert_equal([], data["data"][0]["admin_usernames"])
  end

  def test_response_fields
    record = FactoryBot.create(data_tables_factory_name, {
      :created_at => Time.utc(2017, 1, 1),
      :created_by_id => SecureRandom.uuid,
      :name => "Example",
      :permission_ids => ["analytics", "user_view"],
      :updated_at => Time.utc(2017, 1, 2),
      :updated_by_id => SecureRandom.uuid,
    })
    admin = FactoryBot.create(:admin, :groups => [record])

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

    assert_equal(1, record_data.fetch("admin_usernames").length)
    assert_equal(admin.username, record_data.fetch("admin_usernames").first)
    assert_equal(1, record_data.fetch("api_scope_display_names").length)
    assert_match("- localhost/example", record_data.fetch("api_scope_display_names").first)
    assert_equal(1, record_data.fetch("api_scope_ids").length)
    assert_match_uuid(record_data.fetch("api_scope_ids").first)
    assert_equal(1, record_data.fetch("api_scopes").length)
    assert_kind_of(Hash, record_data.fetch("api_scopes").first)
    assert_equal([
      "host",
      "id",
      "name",
      "path_prefix",
    ].sort, record_data.fetch("api_scopes").first.keys.sort)
    assert_equal("localhost", record_data.fetch("api_scopes").first.fetch("host"))
    assert_match_uuid(record_data.fetch("api_scopes").first.fetch("id"))
    assert_match(%r{^Example \d+$}, record_data.fetch("api_scopes").first.fetch("name"))
    assert_match(%r{^/example/\d+/$}, record_data.fetch("api_scopes").first.fetch("path_prefix"))
    assert_equal("2017-01-01T00:00:00Z", record_data.fetch("created_at"))
    assert_match_uuid(record_data.fetch("created_by"))
    assert_equal(record.created_by_id, record_data.fetch("created_by"))
    assert_equal("Example", record_data.fetch("name"))
    assert_equal(["Analytics", "API Users - View"], record_data.fetch("permission_display_names"))
    assert_equal(["analytics", "user_view"], record_data.fetch("permission_ids"))
    assert_match_uuid(record_data.fetch("updated_by"))
    assert_equal(record.updated_by_id, record_data.fetch("updated_by"))
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

    assert_equal("00000000-1111-2222-3333-444444444444", record_data.fetch("created_by"))
    assert_equal("00000000-1111-2222-3333-444444444444", record_data.fetch("updated_by"))
  end

  def test_search_name
    assert_data_tables_search(:name, "NameSearchTest", "amesearcht")
  end

  def test_order_name
    assert_data_tables_order(:name, ["A", "B"])
  end

  def test_default_order_by_name
    admin_group1 = FactoryBot.create(:admin_group, :name => "A")
    admin_group4 = FactoryBot.create(:admin_group, :name => "Z")
    admin_group2 = FactoryBot.create(:admin_group, :name => "B")
    admin_group3 = FactoryBot.create(:admin_group, :name => "Y")

    response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)

    assert_equal(admin_group1.name, data.fetch("data")[0].fetch("name"))
    assert_equal(admin_group2.name, data.fetch("data")[1].fetch("name"))
    assert_equal(admin_group3.name, data.fetch("data")[2].fetch("name"))
    assert_equal(admin_group4.name, data.fetch("data")[3].fetch("name"))
  end

  def test_csv
    admin_group = FactoryBot.create(:admin_group, {
      :created_at => Time.utc(2017, 1, 1),
      :created_by_id => SecureRandom.uuid,
      :name => "Example",
      :permission_ids => ["analytics", "user_view"],
      :updated_at => Time.utc(2017, 1, 2),
      :updated_by_id => SecureRandom.uuid,
    })
    admin = FactoryBot.create(:admin, :groups => [admin_group])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_groups.csv", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => admin_group.id },
      },
    }))
    assert_response_code(200, response)
    assert_equal("text/csv", response.headers["Content-Type"])
    assert_match("attachment; filename=\"admin_groups_#{Time.now.utc.strftime("%Y-%m-%d")}.csv\"", response.headers["Content-Disposition"])

    csv = CSV.parse(response.body)
    assert_equal(2, csv.length, csv)
    assert_equal([
      "Name",
      "API Scopes",
      "Access",
      "Admins",
    ], csv[0])
    assert_equal([
      admin_group.name,
      admin_group.api_scopes.map { |scope| "#{scope.name} - #{scope.host}#{scope.path_prefix}" }.join("\n"),
      "Analytics\nAPI Users - View",
      admin.username,
    ], csv[1])
  end

  private

  def data_tables_api_url
    "https://127.0.0.1:9081/api-umbrella/v1/admin_groups.json"
  end

  def data_tables_factory_name
    :admin_group
  end

  def data_tables_record_count
    AdminGroup.count
  end

  def assert_base_record_fields(record_data)
    assert_equal([
      "admin_usernames",
      "admins",
      "api_scope_display_names",
      "api_scope_ids",
      "api_scopes",
      "created_at",
      "created_by",
      "creator",
      "deleted_at",
      "id",
      "name",
      "permission_display_names",
      "permission_ids",
      "updated_at",
      "updated_by",
      "updater",
      "version",
    ].sort, record_data.keys.sort)
    assert_kind_of(Array, record_data.fetch("admins"))
    assert_kind_of(Array, record_data.fetch("admin_usernames"))
    assert_kind_of(Array, record_data.fetch("api_scope_display_names"))
    assert_kind_of(Array, record_data.fetch("api_scope_ids"))
    assert_kind_of(Array, record_data.fetch("api_scopes"))
    assert_match_iso8601(record_data.fetch("created_at"))
    assert_match_uuid(record_data.fetch("created_by"))
    assert_kind_of(Hash, record_data.fetch("creator"))
    assert_equal(["username"].sort, record_data.fetch("creator").keys)
    assert_kind_of(String, record_data.fetch("creator").fetch("username"))
    assert_nil(record_data.fetch("deleted_at"))
    assert_match_uuid(record_data.fetch("id"))
    assert_kind_of(String, record_data.fetch("name"))
    assert_kind_of(Array, record_data.fetch("permission_display_names"))
    assert_kind_of(Array, record_data.fetch("permission_ids"))
    assert_match_iso8601(record_data.fetch("updated_at"))
    assert_match_uuid(record_data.fetch("updated_by"))
    assert_kind_of(Hash, record_data.fetch("updater"))
    assert_equal(["username"].sort, record_data.fetch("updater").keys)
    assert_kind_of(String, record_data.fetch("updater").fetch("username"))
    assert_kind_of(Integer, record_data.fetch("version"))
  end
end
