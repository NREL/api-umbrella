require_relative "../../../test_helper"

class Test::Apis::V1::Analytics::TestDrilldownAdminPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    ElasticsearchHelper.clean_es_indices(["2015-01"])
  end

  def test_default_permissions
    factory = :google_log_item
    assert_default_admin_permissions(factory, :required_permissions => ["analytics"])
  end

  private

  def make_request(factory, admin)
    ElasticsearchHelper.clean_es_indices(["2015-01"])
    FactoryBot.create(factory, :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    LogItem.gateway.refresh_index!

    Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
        :prefix => "0/",
      },
    }))
  end

  def assert_admin_permitted(factory, admin)
    response = make_request(factory, admin)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["results"].length)
    assert_equal(1, data["results"][0]["hits"])
    assert_equal(6, data["hits_over_time"]["rows"].length)
    hits_over_time_total = data["hits_over_time"]["rows"].map { |hit| hit["c"][1]["v"] }.sum
    assert_equal(1, hits_over_time_total)
  end

  def assert_admin_forbidden(factory, admin)
    response = make_request(factory, admin)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(0, data["results"].length)
    if(data["hits_over_time"]["rows"].any?)
      assert_equal(6, data["hits_over_time"]["rows"].length)
    end
    hits_over_time_total = data["hits_over_time"]["rows"].map { |hit| if(hit["c"][1]) then hit["c"][1]["v"] else 0 end }.sum
    assert_equal(0, hits_over_time_total)
  end
end
