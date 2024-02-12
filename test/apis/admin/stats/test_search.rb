require_relative "../../../test_helper"

class Test::Apis::Admin::Stats::TestSearch < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    LogItem.clean_indices!
  end

  def test_bins_results_by_day_with_time_zone_support
    Time.use_zone("America/Denver") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-01-12T23:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-01-13T00:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-01-18T23:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-01-19T00:00:00"))
    end
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(2, data["stats"]["total_hits"])
    assert_equal("Tue, Jan 13, 2015", data["hits_over_time"][0]["c"][0]["f"])
    assert_equal(1421132400000, data["hits_over_time"][0]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][0]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][0]["c"][1]["v"])
    assert_equal("Sun, Jan 18, 2015", data["hits_over_time"][5]["c"][0]["f"])
    assert_equal(1421564400000, data["hits_over_time"][5]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][5]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][5]["c"][1]["v"])
  end

  def test_bins_daily_results_daylight_saving_time_begin
    Time.use_zone("UTC") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T00:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T08:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T09:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-09T10:00:00"))
    end
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-03-07",
        :end_at => "2015-03-09",
        :interval => "day",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(4, data["stats"]["total_hits"])
    assert_equal("Sat, Mar 7, 2015", data["hits_over_time"][0]["c"][0]["f"])
    assert_equal(1425711600000, data["hits_over_time"][0]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][0]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][0]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015", data["hits_over_time"][1]["c"][0]["f"])
    assert_equal(1425798000000, data["hits_over_time"][1]["c"][0]["v"])
    assert_equal("2", data["hits_over_time"][1]["c"][1]["f"])
    assert_equal(2, data["hits_over_time"][1]["c"][1]["v"])
    assert_equal("Mon, Mar 9, 2015", data["hits_over_time"][2]["c"][0]["f"])
    assert_equal(1425880800000, data["hits_over_time"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][2]["c"][1]["v"])
  end

  def test_bins_hourly_results_daylight_saving_time_begin
    Time.use_zone("UTC") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T08:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T09:00:00"))
    end
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-03-08",
        :end_at => "2015-03-08",
        :interval => "hour",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(2, data["stats"]["total_hits"])
    assert_equal("Sun, Mar 8, 2015 12:00AM MST", data["hits_over_time"][0]["c"][0]["f"])
    assert_equal(1425798000000, data["hits_over_time"][0]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"][0]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"][0]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015 1:00AM MST", data["hits_over_time"][1]["c"][0]["f"])
    assert_equal(1425801600000, data["hits_over_time"][1]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][1]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][1]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015 3:00AM MDT", data["hits_over_time"][2]["c"][0]["f"])
    assert_equal(1425805200000, data["hits_over_time"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][2]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015 4:00AM MDT", data["hits_over_time"][3]["c"][0]["f"])
    assert_equal(1425808800000, data["hits_over_time"][3]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"][3]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"][3]["c"][1]["v"])
  end

  def test_bins_daily_results_daylight_saving_time_end
    Time.use_zone("UTC") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T00:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T08:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T09:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-03T10:00:00"))
    end
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :search => "",
        :start_at => "2014-11-01",
        :end_at => "2014-11-03",
        :interval => "day",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(4, data["stats"]["total_hits"])
    assert_equal("Sat, Nov 1, 2014", data["hits_over_time"][0]["c"][0]["f"])
    assert_equal(1414821600000, data["hits_over_time"][0]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][0]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][0]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014", data["hits_over_time"][1]["c"][0]["f"])
    assert_equal(1414908000000, data["hits_over_time"][1]["c"][0]["v"])
    assert_equal("2", data["hits_over_time"][1]["c"][1]["f"])
    assert_equal(2, data["hits_over_time"][1]["c"][1]["v"])
    assert_equal("Mon, Nov 3, 2014", data["hits_over_time"][2]["c"][0]["f"])
    assert_equal(1414998000000, data["hits_over_time"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][2]["c"][1]["v"])
  end

  def test_bins_hourly_results_daylight_saving_time_end
    Time.use_zone("UTC") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T08:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T09:00:00"))
    end
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :search => "",
        :start_at => "2014-11-02",
        :end_at => "2014-11-02",
        :interval => "hour",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(2, data["stats"]["total_hits"])
    assert_equal("Sun, Nov 2, 2014 1:00AM MDT", data["hits_over_time"][1]["c"][0]["f"])
    assert_equal(1414911600000, data["hits_over_time"][1]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"][1]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"][1]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014 1:00AM MST", data["hits_over_time"][2]["c"][0]["f"])
    assert_equal(1414915200000, data["hits_over_time"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][2]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014 2:00AM MST", data["hits_over_time"][3]["c"][0]["f"])
    assert_equal(1414918800000, data["hits_over_time"][3]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"][3]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"][3]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014 3:00AM MST", data["hits_over_time"][4]["c"][0]["f"])
    assert_equal(1414922400000, data["hits_over_time"][4]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"][4]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"][4]["c"][1]["v"])
  end

  def test_no_results_non_existent_indices
    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/search.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :search => "",
        :start_at => "2000-01-13",
        :end_at => "2000-01-18",
        :interval => "day",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "hits_over_time" => [
        {
          "c" => [
            { "f" => "Thu, Jan 13, 2000", "v" => 947746800000 },
            { "f" => "0", "v" => 0 },
          ],
        },
        {
          "c" => [
            { "f" => "Fri, Jan 14, 2000", "v" => 947833200000 },
            { "f" => "0", "v" => 0 },
          ],
        },
        {
          "c" => [
            { "f" => "Sat, Jan 15, 2000", "v" => 947919600000 },
            { "f" => "0", "v" => 0 },
          ],
        },
        {
          "c" => [
            { "f" => "Sun, Jan 16, 2000", "v" => 948006000000 },
            { "f" => "0", "v" => 0 },
          ],
        },
        {
          "c" => [
            { "f" => "Mon, Jan 17, 2000", "v" => 948092400000 },
            { "f" => "0", "v" => 0 },
          ],
        },
        {
          "c" => [
            { "f" => "Tue, Jan 18, 2000", "v" => 948178800000 },
            { "f" => "0", "v" => 0 },
          ],
        },
      ],
      "stats" => {
        "total_users" => 0,
        "total_ips" => 0,
        "total_hits" => 0,
        "average_response_time" => nil,
      },
      "aggregations" => {
        "ips" => [],
        "users" => [],
      },
    }, data)
  end
end
