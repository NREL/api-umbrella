require_relative "../../../test_helper"

class Test::Apis::V1::WebsiteBackends::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  include ApiUmbrellaSharedTests::DataTablesApi

  def test_csv
    website_backend = FactoryBot.create(:website_backend)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/website_backends.csv", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => website_backend.id },
      },
    }))
    assert_response_code(200, response)
    assert_equal("text/csv", response.headers["Content-Type"])
    assert_match("attachment; filename=\"website_backends_#{Time.now.utc.strftime("%Y-%m-%d")}.csv\"", response.headers["Content-Disposition"])

    csv = CSV.parse(response.body)
    assert_equal(2, csv.length, csv)
    assert_equal([
      "Host",
    ], csv[0])
    assert_equal([
      website_backend.frontend_host,
    ], csv[1])
  end

  private

  def data_tables_api_url
    "https://127.0.0.1:9081/api-umbrella/v1/website_backends.json"
  end

  def data_tables_factory_name
    :website_backend
  end

  def data_tables_record_count
    WebsiteBackend.count
  end
end
