require_relative "../../test_helper"

class Test::Apis::V0::TestAnalytics < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    LogItem.clean_indices!
  end

  def test_forbids_api_key_without_any_role
    user = FactoryBot.create(:api_user)
    response = make_request(user)
    assert_response_code(401, response)
  end

  def test_forbids_api_key_without_correct_role
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

  def test_allows_api_key_without_role_if_configured
    user = FactoryBot.create(:api_user)
    response = make_request(user)
    assert_response_code(401, response)

    override_config({
      "web" => {
        "analytics_v0_summary_required_role" => nil,
      },
    }) do
      response = make_request(user)
      assert_response_code(200, response)
    end
  end

  def test_expected_response
    backend1 = FactoryBot.create(:api_backend, :frontend_host => "localhost1")
    backend2 = FactoryBot.create(:api_backend, :frontend_host => "localhost2")
    backend3 = FactoryBot.create(:api_backend, :organization_name => "Another Org", :frontend_host => "localhost3")
    backend4 = FactoryBot.create(:api_backend, :status_description => nil, :frontend_host => "localhost4")

    start_time = nil
    end_time = nil
    Time.use_zone($config["analytics"]["timezone"]) do
      start_time = Time.zone.parse($config["web"]["analytics_v0_summary_start_time"])
      end_time = Time.zone.parse($config["web"]["analytics_v0_summary_end_time"])
    end
    FactoryBot.create_list(:api_user, 3, :created_at => start_time)
    FactoryBot.create_list(:log_item, 1, :request_at => start_time, :response_time => 100, :request_host => backend1.frontend_host, :request_path => backend1.url_matches[0].frontend_prefix)
    FactoryBot.create_list(:log_item, 1, :request_at => start_time, :response_time => 100, :request_host => backend2.frontend_host, :request_path => backend2.url_matches[0].frontend_prefix)
    FactoryBot.create_list(:log_item, 1, :request_at => start_time, :response_time => 100, :request_host => backend3.frontend_host, :request_path => backend3.url_matches[0].frontend_prefix)
    FactoryBot.create_list(:log_item, 1, :request_at => start_time, :response_time => 100, :request_host => backend4.frontend_host, :request_path => backend4.url_matches[0].frontend_prefix)
    FactoryBot.create_list(:log_item, 1, :request_at => end_time, :response_time => 200, :request_host => backend1.frontend_host, :request_path => backend1.url_matches[0].frontend_prefix)
    LogItem.refresh_indices!

    response = make_request
    assert_response_code(200, response)
    assert_equal("MISS", response.headers["X-Cache"])

    data = MultiJson.load(response.body)
    assert_equal([
      "cached_at",
      "end_time",
      "production_apis",
      "start_time",
      "timezone",
    ].sort, data.keys.sort)
    assert_match_iso8601(data.fetch("cached_at"))
    assert_match_iso8601(data.fetch("end_time"))
    assert_kind_of(Hash, data.fetch("production_apis"))
    assert_match_iso8601(data.fetch("start_time"))
    assert_equal("2013-07-01T06:00:00Z", data.fetch("start_time"))
    assert_equal("America/Denver", data.fetch("timezone"))

    assert_equal({
      "organizations" => [
        {
          "active_api_keys" => {
            "monthly" => [
              ["2013-07", 1],
              ["2013-08", 0],
            ],
            "recent" => {
              "total" => 0,
              "daily" => [
                ["2013-08-31", 0],
              ],
            },
            "total" => 1,
          },
          "average_response_times" => {
            "average" => 100,
            "monthly" => [
              ["2013-07", 100],
              ["2013-08", nil],
            ],
            "recent" => {
              "average" => nil,
              "daily" => [
                ["2013-08-31", nil],
              ],
            },
          },
          "api_backend_url_match_count" => 1,
          "name" => "Another Org",
          "api_backend_count" => 1,
          "hits" => {
            "monthly" => [
              ["2013-07", 1],
              ["2013-08", 0],
            ],
            "recent" => {
              "total" => 0,
              "daily" => [
                ["2013-08-31", 0],
              ],
            },
            "total" => 1,
          },
        },
        {
          "active_api_keys" => {
            "monthly" => [
              ["2013-07", 1],
              ["2013-08", 1],
            ],
            "recent" => {
              "total" => 1,
              "daily" => [
                ["2013-08-31", 1],
              ],
            },
            "total" => 1,
          },
          "average_response_times" => {
            "average" => 133,
            "monthly" => [
              ["2013-07", 100],
              ["2013-08", 200],
            ],
            "recent" => {
              "average" => 200,
              "daily" => [
                ["2013-08-31", 200],
              ],
            },
          },
          "api_backend_url_match_count" => 2,
          "name" => "Example Org",
          "api_backend_count" => 2,
          "hits" => {
            "monthly" => [
              ["2013-07", 2],
              ["2013-08", 1],
            ],
            "recent" => {
              "total" => 1,
              "daily" => [
                ["2013-08-31", 1],
              ],
            },
            "total" => 3,
          },
        },
      ],
      "all" => {
        "active_api_keys" => {
          "monthly" => [
            ["2013-07", 1],
            ["2013-08", 1],
          ],
          "recent" => {
            "total" => 1,
            "daily" => [
              ["2013-08-31", 1],
            ],
          },
          "total" => 1,
        },
        "average_response_times" => {
          "average" => 125,
          "monthly" => [
            ["2013-07", 100],
            ["2013-08", 200],
          ],
          "recent" => {
            "average" => 200,
            "daily" => [
              ["2013-08-31", 200],
            ],
          },
        },
        "hits" => {
          "monthly" => [
            ["2013-07", 3],
            ["2013-08", 1],
          ],
          "recent" => {
            "total" => 1,
            "daily" => [
              ["2013-08-31", 1],
            ],
          },
          "total" => 4,
        },
      },
      "api_backend_count" => 3,
      "organization_count" => 2,
      "api_backend_url_match_count" => 3,
    }, data.fetch("production_apis"))

    assert_equal([
      "all",
      "api_backend_count",
      "api_backend_url_match_count",
      "organization_count",
      "organizations",
    ].sort, data.fetch("production_apis").keys.sort)
  end

  def test_caches_results
    assert_equal(0, Cache.count)

    response = make_request
    assert_equal("MISS", response.headers["X-Cache"])
    assert_equal(2, Cache.count)

    response = make_request
    assert_equal("HIT", response.headers["X-Cache"])
    assert_equal(2, Cache.count)

    cache = Cache.find_by!(:id => "analytics_summary")
    assert_equal("analytics_summary", cache.id)
    assert_in_delta(Time.now.to_i, cache.created_at.to_i, 10)
    assert_in_delta(Time.now.to_i + (60 * 60 * 24 * 2), cache.expires_at.to_i, 10)
    assert(cache.data)
    data = MultiJson.load(cache.data)
    assert_equal([
      "cached_at",
      "end_time",
      "production_apis",
      "start_time",
      "timezone",
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
