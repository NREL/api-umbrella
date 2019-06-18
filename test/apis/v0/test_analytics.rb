require_relative "../../test_helper"

class Test::Apis::V0::TestAnalytics < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    LogItem.clean_indices!
  end

  def test_forbids_api_key_without_role
    user = FactoryBot.create(:api_user, {
      :roles => ["api-umbrella-public-metricsx"],
    })

    response = make_request(user)
    assert_response_code(401, response)
  end

  def test_allows_api_key_with_role
    response = make_request
    assert_response_code(200, response)
  end

  def test_expected_response
    start_time = nil
    end_time = nil
    Time.use_zone($config["analytics"]["timezone"]) do
      start_time = Time.zone.parse($config["web"]["analytics_v0_summary_start_time"].iso8601(3))
      end_time = Time.zone.parse($config["web"]["analytics_v0_summary_end_time"].iso8601(3))
    end
    FactoryBot.create_list(:api_user, 3, :created_at => start_time)
    FactoryBot.create_list(:log_item, 1, :request_at => start_time)
    FactoryBot.create_list(:log_item, 2, :request_at => end_time)
    LogItem.refresh_indices!

    response = make_request
    assert_response_code(200, response)
    assert_equal("MISS", response.headers["X-Cache"])

    data = MultiJson.load(response.body)
    assert_operator(data["total_hits"], :>, 0)
    assert_operator(data["total_users"], :>, 0)
    assert_kind_of(Array, data["hits_by_month"])
    assert_kind_of(Array, data["users_by_month"])

    assert_equal({
      "year" => start_time.year,
      "month" => start_time.month,
      "count" => 1,
    }, data["hits_by_month"][0])
    assert_equal({
      "year" => end_time.year,
      "month" => end_time.month,
      "count" => 2,
    }, data["hits_by_month"][1])

    assert_equal({
      "year" => start_time.year,
      "month" => start_time.month,
      "count" => 3,
    }, data["users_by_month"][0])
    assert_equal({
      "year" => end_time.year,
      "month" => end_time.month,
      "count" => 0,
    }, data["users_by_month"][1])
  end

  def test_caches_results
    assert_equal(0, Cache.count)

    response = make_request
    assert_equal("MISS", response.headers["X-Cache"])
    assert_equal(3, Cache.count)

    response = make_request
    assert_equal("HIT", response.headers["X-Cache"])
    assert_equal(3, Cache.count)

    cache = Cache.find_by!(:id => "analytics_summary")
    assert_equal("analytics_summary", cache.id)
    assert_in_delta(Time.now.to_i, cache.created_at.to_i, 10)
    assert_in_delta(Time.now.to_i + 60 * 60 * 24 * 2, cache.expires_at.to_i, 10)
    assert(cache.data)
    data = MultiJson.load(cache.data)
    assert_equal([
      "cached_at",
      "end_time",
      "hits_by_month",
      "production_apis",
      "start_time",
      "total_hits",
      "total_users",
      "users_by_month",
    ].sort, data.keys.sort)
  end

  private

  def make_request(user = nil)
    user ||= FactoryBot.create(:api_user, :roles => ["api-umbrella-public-metrics"])

    Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v0/analytics/summary.json", http_options.deep_merge({
      :headers => { "X-Api-Key" => user.api_key },
    }))
  end
end
