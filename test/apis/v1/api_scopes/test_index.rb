require_relative "../../../test_helper"

class Test::Apis::V1::ApiScopes::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  include ApiUmbrellaSharedTests::DataTablesApi

  def test_response_fields
    record = FactoryBot.create(data_tables_factory_name, {
      :created_at => Time.utc(2017, 1, 1),
      :created_by_id => SecureRandom.uuid,
      :host => "example.com",
      :name => "Example",
      :path_prefix => "/#{unique_test_id}/",
      :updated_at => Time.utc(2017, 1, 2),
      :updated_by_id => SecureRandom.uuid,
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

    assert_equal([], record_data.fetch("admin_groups"))
    assert_equal([], record_data.fetch("apis"))
    assert_equal("2017-01-01T00:00:00Z", record_data.fetch("created_at"))
    assert_match_uuid(record_data.fetch("created_by"))
    assert_equal(record.created_by_id, record_data.fetch("created_by"))
    assert_equal("example.com", record_data.fetch("host"))
    assert_equal("Example", record_data.fetch("name"))
    assert_equal("/#{unique_test_id}/", record_data.fetch("path_prefix"))
    assert_equal("2017-01-02T00:00:00Z", record_data.fetch("updated_at"))
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

  def test_search_host
    assert_data_tables_search(:host, "hostsearchtest.com", "ostsearcht")
  end

  def test_search_path_prefix
    assert_data_tables_search(:path_prefix, "/path-prefix/search-test/", "refix/searc")
  end

  def test_order_name
    assert_data_tables_order(:name, ["A", "B"])
  end

  def test_order_host
    assert_data_tables_order(:host, ["a.example.com", "b.example.com"])
  end

  def test_order_path_prefix
    assert_data_tables_order(:path_prefix, ["/a", "/b"])
  end

  def test_default_order_by_name
    api_scope1 = FactoryBot.create(:api_scope, :name => "A")
    api_scope4 = FactoryBot.create(:api_scope, :name => "Z")
    api_scope2 = FactoryBot.create(:api_scope, :name => "B")
    api_scope3 = FactoryBot.create(:api_scope, :name => "Y")

    response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)

    assert_equal(api_scope1.name, data.fetch("data")[0].fetch("name"))
    assert_equal(api_scope2.name, data.fetch("data")[1].fetch("name"))
    assert_equal(api_scope3.name, data.fetch("data")[2].fetch("name"))
    assert_equal(api_scope4.name, data.fetch("data")[3].fetch("name"))
  end

  def test_csv
    api_scope = FactoryBot.create(:api_scope)
    admin_group = FactoryBot.create(:admin_group, :api_scopes => [api_scope])
    api_backend = FactoryBot.create(:api_backend, :frontend_host => api_scope.host, :url_matches => [FactoryBot.build(:api_backend_url_match, :frontend_prefix => api_scope.path_prefix)])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/api_scopes.csv", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => api_scope.id },
      },
    }))
    assert_response_code(200, response)
    assert_equal("text/csv", response.headers["Content-Type"])
    assert_match("attachment; filename=\"api_scopes_#{Time.now.utc.strftime("%Y-%m-%d")}.csv\"", response.headers["Content-Disposition"])

    csv = CSV.parse(response.body)
    assert_equal(2, csv.length, csv)
    assert_equal([
      "Name",
      "Host",
      "Path Prefix",
      "Admin Groups",
      "API Backends",
    ], csv[0])
    assert_equal([
      api_scope.name,
      api_scope.host,
      api_scope.path_prefix,
      admin_group.name,
      api_backend.name,
    ], csv[1])
  end

  private

  def data_tables_api_url
    "https://127.0.0.1:9081/api-umbrella/v1/api_scopes.json"
  end

  def data_tables_factory_name
    :api_scope
  end

  def data_tables_record_count
    ApiScope.count
  end

  def assert_base_record_fields(record_data)
    assert_equal([
      "admin_groups",
      "apis",
      "created_at",
      "created_by",
      "creator",
      "deleted_at",
      "host",
      "id",
      "name",
      "path_prefix",
      "updated_at",
      "updated_by",
      "updater",
      "version",
    ].sort, record_data.keys.sort)
    assert_kind_of(Array, record_data.fetch("admin_groups"))
    assert_kind_of(Array, record_data.fetch("apis"))
    assert_match_iso8601(record_data.fetch("created_at"))
    assert_match_uuid(record_data.fetch("created_by"))
    assert_kind_of(Hash, record_data.fetch("creator"))
    assert_equal(["username"].sort, record_data.fetch("creator").keys)
    assert_kind_of(String, record_data.fetch("creator").fetch("username"))
    assert_nil(record_data.fetch("deleted_at"))
    assert_kind_of(String, record_data.fetch("host"))
    assert_match_uuid(record_data.fetch("id"))
    assert_kind_of(String, record_data.fetch("name"))
    assert_kind_of(String, record_data.fetch("path_prefix"))
    assert_match_iso8601(record_data.fetch("updated_at"))
    assert_match_uuid(record_data.fetch("updated_by"))
    assert_kind_of(Hash, record_data.fetch("updater"))
    assert_equal(["username"].sort, record_data.fetch("updater").keys)
    assert_kind_of(String, record_data.fetch("updater").fetch("username"))
    assert_kind_of(Integer, record_data.fetch("version"))
  end
end
