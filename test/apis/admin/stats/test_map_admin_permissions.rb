require_relative "../../../test_helper"

class Test::Apis::Admin::Stats::TestMapAdminPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
  end

  def test_default_permissions
    factory = :google_log_item
    assert_default_admin_permissions(factory, :required_permissions => ["analytics"])
  end

  private

  def make_request(factory, admin)
    FactoryBot.create(factory, :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    LogItem.gateway.refresh_index!

    Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session(admin)).deep_merge({
      :params => {
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "world",
      },
    }))
  end

  def assert_admin_permitted(factory, admin)
    response = make_request(factory, admin)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["map_regions"].length)
    assert_equal(1, data["regions"].length)
  end

  def assert_admin_forbidden(factory, admin)
    response = make_request(factory, admin)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(0, data["map_regions"].length)
    assert_equal(0, data["regions"].length)
  end
end
