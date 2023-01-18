require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  include ApiUmbrellaSharedTests::DataTablesApi

  def test_search_name
    assert_data_tables_search(:name, "NameFieldSearch#{unique_test_id}Test", "amefieldsearch#{unique_test_id}t")
  end

  def test_search_frontend_host
    assert_data_tables_search(:frontend_host, unique_test_hostname, unique_test_hostname)
  end

  def test_search_backend_host
    assert_data_tables_search(:backend_host, unique_test_hostname, unique_test_hostname)
  end

  def test_search_server_hosts
    assert_data_tables_search(:servers, [FactoryBot.build(:api_backend_server, :host => "/#{unique_test_id}-server-host")], "#{unique_test_id}-server")
  end

  def test_search_url_match_frontend_prefixes
    assert_data_tables_search(:url_matches, [FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/#{unique_test_id}-frontend-host")], "#{unique_test_id}-frontend")
  end

  def test_search_url_match_backend_prefixes
    assert_data_tables_search(:url_matches, [FactoryBot.build(:api_backend_url_match, :backend_prefix => "/#{unique_test_id}-backend-prefix")], "#{unique_test_id}-backend")
  end

  def test_search_counts_with_url_match_joins
    assert_data_tables_search(:url_matches, [
      FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/#{unique_test_id}-prefix1"),
      FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/#{unique_test_id}-prefix2"),
      FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/#{unique_test_id}-prefix3"),
    ], "#{unique_test_id}-prefix")
  end

  def test_csv
    api_scope = FactoryBot.create(:api_scope)
    admin_group = FactoryBot.create(:admin_group, :api_scopes => [api_scope])
    api_backend = FactoryBot.create(:api_backend, :frontend_host => api_scope.host, :url_matches => [FactoryBot.build(:api_backend_url_match, :frontend_prefix => api_scope.path_prefix)])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.csv", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => api_backend.id },
      },
    }))
    assert_response_code(200, response)
    assert_equal("text/csv", response.headers["Content-Type"])
    assert_match("attachment; filename=\"apis_#{Time.now.utc.strftime("%Y-%m-%d")}.csv\"", response.headers["Content-Disposition"])

    csv = CSV.parse(response.body)
    assert_equal(2, csv.length, csv)
    assert_equal([
      "Name",
      "Host",
      "Prefixes",
      "Organization Name",
      "Status",
      "Root API Scope",
      "API Scopes",
      "Admin Groups",
    ], csv[0])
    assert_equal([
      api_backend.name,
      api_backend.frontend_host,
      api_backend.url_matches.map { |url_match| url_match.frontend_prefix }.join("\n"),
      api_backend.organization_name,
      api_backend.status_description,
      api_scope.name,
      api_scope.name,
      admin_group.name,
    ], csv[1])
  end

  private

  def data_tables_api_url
    "https://127.0.0.1:9081/api-umbrella/v1/apis.json"
  end

  def data_tables_factory_name
    :api_backend
  end

  def data_tables_record_count
    ApiBackend.count
  end
end
