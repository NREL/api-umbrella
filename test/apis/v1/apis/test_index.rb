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
