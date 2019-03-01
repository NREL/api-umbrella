require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Api.delete_all
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
    assert_data_tables_search(:servers, [FactoryBot.build(:api_server, :host => "/#{unique_test_id}-server-host")], "#{unique_test_id}-server")
  end

  def test_search_url_match_frontend_prefixes
    assert_data_tables_search(:url_matches, [FactoryBot.build(:api_url_match, :frontend_prefix => "/#{unique_test_id}-frontend-host")], "#{unique_test_id}-frontend")
  end

  def test_search_url_match_backend_prefixes
    assert_data_tables_search(:url_matches, [FactoryBot.build(:api_url_match, :backend_prefix => "/#{unique_test_id}-backend-prefix")], "#{unique_test_id}-backend")
  end

  def test_search_counts_with_url_match_joins
    assert_data_tables_search(:url_matches, [
      FactoryBot.build(:api_url_match, :frontend_prefix => "/#{unique_test_id}-prefix1"),
      FactoryBot.build(:api_url_match, :frontend_prefix => "/#{unique_test_id}-prefix2"),
      FactoryBot.build(:api_url_match, :frontend_prefix => "/#{unique_test_id}-prefix3"),
    ], "#{unique_test_id}-prefix")
  end

  private

  def data_tables_api_url
    "https://127.0.0.1:9081/api-umbrella/v1/apis.json"
  end

  def data_tables_factory_name
    :api
  end

  def data_tables_record_count
    Api.where(:deleted_at => nil).count
  end
end
