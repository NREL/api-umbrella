require_relative "../../../test_helper"

class Test::Apis::V1::ApiScopes::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    ApiScope.delete_all
  end

  include ApiUmbrellaSharedTests::DataTablesApi

  def test_response_fields
    record = FactoryBot.create(data_tables_factory_name, {
      :created_at => Time.utc(2017, 1, 1),
      :created_by => SecureRandom.uuid,
      :host => "example.com",
      :name => "Example",
      :path_prefix => "/#{unique_test_id}/",
      :updated_at => Time.utc(2017, 1, 2),
      :updated_by => SecureRandom.uuid,
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

    assert_equal("2017-01-01T00:00:00Z", record_data.fetch("created_at"))
    assert_match_uuid(record_data.fetch("created_by"))
    assert_equal(record.created_by, record_data.fetch("created_by"))
    assert_equal("example.com", record_data.fetch("host"))
    assert_equal("Example", record_data.fetch("name"))
    assert_equal("/#{unique_test_id}/", record_data.fetch("path_prefix"))
    assert_equal("2017-01-02T00:00:00Z", record_data.fetch("updated_at"))
    assert_match_uuid(record_data.fetch("updated_by"))
    assert_equal(record.updated_by, record_data.fetch("updated_by"))
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

    assert_nil(record_data.fetch("created_by"))
    assert_nil(record_data.fetch("updated_by"))
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

  private

  def data_tables_api_url
    "https://127.0.0.1:9081/api-umbrella/v1/api_scopes.json"
  end

  def data_tables_factory_name
    :api_scope
  end

  def data_tables_record_count
    ApiScope.where(:deleted_at => nil).count
  end

  def assert_base_record_fields(record_data)
    assert_equal([
      "created_at",
      "created_by",
      "deleted_at",
      "host",
      "id",
      "name",
      "path_prefix",
      "updated_at",
      "updated_by",
      "version",
    ].sort, record_data.keys.sort)
    assert_match_iso8601(record_data.fetch("created_at"))
    assert_nil(record_data.fetch("deleted_at"))
    assert_kind_of(String, record_data.fetch("host"))
    assert_match_uuid(record_data.fetch("id"))
    assert_kind_of(String, record_data.fetch("name"))
    assert_kind_of(String, record_data.fetch("path_prefix"))
    assert_match_iso8601(record_data.fetch("updated_at"))
    assert_kind_of(Integer, record_data.fetch("version"))
  end
end
