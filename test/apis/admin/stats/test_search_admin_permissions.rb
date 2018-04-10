require_relative "../../../test_helper"

class Test::Apis::Admin::Stats::TestSearchAdminPermissions < Minitest::Test
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

    Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session(admin)).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
      },
    }))
  end

  def assert_admin_permitted(factory, admin)
    response = make_request(factory, admin)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["stats"]["total_hits"])
    assert_equal(1, data["stats"]["total_users"])
    assert_equal(1, data["stats"]["total_ips"])
    assert_equal(1, data["aggregations"]["users"].length)
    assert_equal(1, data["aggregations"]["ips"].length)
    assert_equal(6, data["hits_over_time"].length)
    hits_over_time_total = data["hits_over_time"].map { |hit| hit["c"][1]["v"] }.sum
    assert_equal(1, hits_over_time_total)
  end

  def assert_admin_forbidden(factory, admin)
    response = make_request(factory, admin)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(0, data["stats"]["total_hits"])
    assert_nil(data["stats"]["average_response_time"])
    if(data["hits_over_time"].present?)
      assert_equal(0, data["stats"]["total_users"])
      assert_equal(0, data["stats"]["total_ips"])
      assert_equal(6, data["hits_over_time"].length)
    else
      assert_nil(data["stats"]["total_users"])
      assert_nil(data["stats"]["total_ips"])
      assert_equal(0, data["hits_over_time"].length)
    end
    hits_over_time_total = data["hits_over_time"].map { |hit| hit["c"][1]["v"] }.sum
    assert_equal(0, hits_over_time_total)
  end
end
