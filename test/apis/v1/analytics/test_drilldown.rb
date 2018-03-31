require_relative "../../../test_helper"

class Test::Apis::V1::Analytics::TestDrilldown < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
  end

  def test_level0_prefix
    FactoryBot.create_list(:log_item, 2, :request_hierarchy => ["0/127.0.0.1/", "1/127.0.0.1/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create(:log_item, :request_hierarchy => ["0/example.com/", "1/example.com/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
        :prefix => "0/",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(2, data["results"].length)
    assert_equal({
      "depth" => 0,
      "path" => "127.0.0.1/",
      "terminal" => false,
      "descendent_prefix" => "1/127.0.0.1/",
      "hits" => 2,
    }, data["results"][0])
    assert_equal([
      { "id" => "date", "label" => "Date", "type" => "datetime" },
      { "id" => "0/127.0.0.1/", "label" => "127.0.0.1/", "type" => "number" },
      { "id" => "0/example.com/", "label" => "example.com/", "type" => "number" },
    ], data["hits_over_time"]["cols"])
    assert_equal(6, data["hits_over_time"]["rows"].length)
    assert_equal({ "c" => [
      { "v" => 1421218800000, "f" => "Wed, Jan 14, 2015" },
      { "v" => 2, "f" => "2" },
      { "v" => 1, "f" => "1" },
    ] }, data["hits_over_time"]["rows"][1])
  end

  def test_level1_prefix
    FactoryBot.create_list(:log_item, 2, :request_hierarchy => ["0/127.0.0.1/", "1/127.0.0.1/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create(:log_item, :request_hierarchy => ["0/example.com/", "1/example.com/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
        :prefix => "1/example.com/",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["results"].length)
    assert_equal({
      "depth" => 1,
      "path" => "example.com/hello",
      "terminal" => true,
      "descendent_prefix" => "2/example.com/hello",
      "hits" => 1,
    }, data["results"][0])
    assert_equal([
      { "id" => "date", "label" => "Date", "type" => "datetime" },
      { "id" => "1/example.com/hello", "label" => "example.com/hello", "type" => "number" },
    ], data["hits_over_time"]["cols"])
    assert_equal(6, data["hits_over_time"]["rows"].length)
    assert_equal({ "c" => [
      { "v" => 1421218800000, "f" => "Wed, Jan 14, 2015" },
      { "v" => 1, "f" => "1" },
    ] }, data["hits_over_time"]["rows"][1])
  end

  def test_prefix_not_contains
    FactoryBot.create_list(:log_item, 2, :request_hierarchy => ["0/127.0.0.1/", "1/127.0.0.1/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    # Ensure that the second element in the array also contains "0/" to
    # ensure that the filtering and terms aggregations are both matching
    # based on prefix only.
    FactoryBot.create(:log_item, :request_hierarchy => ["0/0/", "1/0/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create(:log_item, :request_hierarchy => ["foo/0/", "foo/0/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
        :prefix => "0/",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(2, data["results"].length)
    assert_equal({
      "depth" => 0,
      "path" => "127.0.0.1/",
      "terminal" => false,
      "descendent_prefix" => "1/127.0.0.1/",
      "hits" => 2,
    }, data["results"][0])
    assert_equal([
      { "id" => "date", "label" => "Date", "type" => "datetime" },
      { "id" => "0/127.0.0.1/", "label" => "127.0.0.1/", "type" => "number" },
      { "id" => "0/0/", "label" => "0/", "type" => "number" },
    ], data["hits_over_time"]["cols"])
    assert_equal(6, data["hits_over_time"]["rows"].length)
    assert_equal({ "c" => [
      { "v" => 1421218800000, "f" => "Wed, Jan 14, 2015" },
      { "v" => 2, "f" => "2" },
      { "v" => 1, "f" => "1" },
    ] }, data["hits_over_time"]["rows"][1])
  end

  def test_prefix_regex_escaping
    FactoryBot.create_list(:log_item, 2, :request_hierarchy => ["0/127.0.0.1/", "1/127.0.0.1/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create(:log_item, :request_hierarchy => ["0/example.com/", "1/example.com/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    # Add other items in the request_hierarchy array that would match "0/."
    # (even though this isn't really a valid hierarchy definition). This
    # ensures that we also test whether the terms aggregations are being
    # escaped (and not just the overall filter).
    FactoryBot.create(:log_item, :request_hierarchy => ["0/.com/", "0/xcom", "0/ycom", "1/.com/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
        :prefix => "0/.",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["results"].length)
    assert_equal({
      "depth" => 0,
      "path" => ".com/",
      "terminal" => false,
      "descendent_prefix" => "1/.com/",
      "hits" => 1,
    }, data["results"][0])
    assert_equal([
      { "id" => "date", "label" => "Date", "type" => "datetime" },
      { "id" => "0/.com/", "label" => ".com/", "type" => "number" },
    ], data["hits_over_time"]["cols"])
    assert_equal(6, data["hits_over_time"]["rows"].length)
    assert_equal({ "c" => [
      { "v" => 1421218800000, "f" => "Wed, Jan 14, 2015" },
      { "v" => 1, "f" => "1" },
    ] }, data["hits_over_time"]["rows"][1])
  end

  def test_all_results_top_10_for_chart
    FactoryBot.create_list(:log_item, 2, :request_hierarchy => ["0/127.0.0.1/", "1/127.0.0.1/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 2, :request_hierarchy => ["0/127.0.0.2/", "1/127.0.0.2/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 3, :request_hierarchy => ["0/127.0.0.3/", "1/127.0.0.3/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 10, :request_hierarchy => ["0/127.0.0.4/", "1/127.0.0.4/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 11, :request_hierarchy => ["0/127.0.0.5/", "1/127.0.0.5/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 12, :request_hierarchy => ["0/127.0.0.6/", "1/127.0.0.6/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 13, :request_hierarchy => ["0/127.0.0.7/", "1/127.0.0.7/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 14, :request_hierarchy => ["0/127.0.0.8/", "1/127.0.0.8/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 15, :request_hierarchy => ["0/127.0.0.9/", "1/127.0.0.9/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 16, :request_hierarchy => ["0/127.0.0.10/", "1/127.0.0.10/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 17, :request_hierarchy => ["0/127.0.0.11/", "1/127.0.0.11/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 18, :request_hierarchy => ["0/127.0.0.12/", "1/127.0.0.12/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    FactoryBot.create_list(:log_item, 1, :request_hierarchy => ["0/127.0.0.13/", "1/127.0.0.13/hello"], :request_at => Time.parse("2015-01-15T00:00:00Z").utc)
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
        :prefix => "0/",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(13, data["results"].length)
    assert_equal({
      "depth" => 0,
      "path" => "127.0.0.12/",
      "terminal" => false,
      "descendent_prefix" => "1/127.0.0.12/",
      "hits" => 18,
    }, data["results"][0])
    assert_equal({
      "depth" => 0,
      "path" => "127.0.0.13/",
      "terminal" => false,
      "descendent_prefix" => "1/127.0.0.13/",
      "hits" => 1,
    }, data["results"][12])
    assert_equal([
      { "id" => "date", "label" => "Date", "type" => "datetime" },
      { "id" => "0/127.0.0.12/", "label" => "127.0.0.12/", "type" => "number" },
      { "id" => "0/127.0.0.11/", "label" => "127.0.0.11/", "type" => "number" },
      { "id" => "0/127.0.0.10/", "label" => "127.0.0.10/", "type" => "number" },
      { "id" => "0/127.0.0.9/", "label" => "127.0.0.9/", "type" => "number" },
      { "id" => "0/127.0.0.8/", "label" => "127.0.0.8/", "type" => "number" },
      { "id" => "0/127.0.0.7/", "label" => "127.0.0.7/", "type" => "number" },
      { "id" => "0/127.0.0.6/", "label" => "127.0.0.6/", "type" => "number" },
      { "id" => "0/127.0.0.5/", "label" => "127.0.0.5/", "type" => "number" },
      { "id" => "0/127.0.0.4/", "label" => "127.0.0.4/", "type" => "number" },
      { "id" => "0/127.0.0.3/", "label" => "127.0.0.3/", "type" => "number" },
      { "id" => "other", "label" => "Other", "type" => "number" },
    ], data["hits_over_time"]["cols"])
    assert_equal(6, data["hits_over_time"]["rows"].length)
    assert_equal({ "c" => [
      { "v" => 1421218800000, "f" => "Wed, Jan 14, 2015" },
      { "v" => 18, "f" => "18" },
      { "v" => 17, "f" => "17" },
      { "v" => 16, "f" => "16" },
      { "v" => 15, "f" => "15" },
      { "v" => 14, "f" => "14" },
      { "v" => 13, "f" => "13" },
      { "v" => 12, "f" => "12" },
      { "v" => 11, "f" => "11" },
      { "v" => 10, "f" => "10" },
      { "v" => 3, "f" => "3" },
      { "v" => 5, "f" => "5" },
    ] }, data["hits_over_time"]["rows"][1])
  end

  def test_time_zone
    Time.use_zone("America/Denver") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-01-12T23:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-01-13T00:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-01-18T23:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-01-19T00:00:00"))
    end
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
        :prefix => "0/",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_operator(data["results"].length, :>, 0)
    assert_equal(2, data["results"][0]["hits"])
    assert_equal("Tue, Jan 13, 2015", data["hits_over_time"]["rows"][0]["c"][0]["f"])
    assert_equal(1421132400000, data["hits_over_time"]["rows"][0]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][0]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][0]["c"][1]["v"])
    assert_equal("Sun, Jan 18, 2015", data["hits_over_time"]["rows"][5]["c"][0]["f"])
    assert_equal(1421564400000, data["hits_over_time"]["rows"][5]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][5]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][5]["c"][1]["v"])
  end

  def test_bins_daily_results_daylight_saving_time_begin
    LogItem.index_name = "api-umbrella-logs-write-2015-03"
    Time.use_zone("UTC") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T00:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T08:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T09:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-09T10:00:00"))
    end
    LogItem.gateway.refresh_index!
    LogItem.index_name = "api-umbrella-logs-write-2015-01"

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-03-07",
        :end_at => "2015-03-09",
        :interval => "day",
        :prefix => "0/",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_operator(data["results"].length, :>, 0)
    assert_equal(4, data["results"][0]["hits"])
    assert_equal("Sat, Mar 7, 2015", data["hits_over_time"]["rows"][0]["c"][0]["f"])
    assert_equal(1425711600000, data["hits_over_time"]["rows"][0]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][0]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][0]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015", data["hits_over_time"]["rows"][1]["c"][0]["f"])
    assert_equal(1425798000000, data["hits_over_time"]["rows"][1]["c"][0]["v"])
    assert_equal("2", data["hits_over_time"]["rows"][1]["c"][1]["f"])
    assert_equal(2, data["hits_over_time"]["rows"][1]["c"][1]["v"])
    assert_equal("Mon, Mar 9, 2015", data["hits_over_time"]["rows"][2]["c"][0]["f"])
    assert_equal(1425880800000, data["hits_over_time"]["rows"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][2]["c"][1]["v"])
  end

  def test_bins_hourly_results_daylight_saving_time_begin
    LogItem.index_name = "api-umbrella-logs-write-2015-03"
    Time.use_zone("UTC") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T08:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2015-03-08T09:00:00"))
    end
    LogItem.gateway.refresh_index!
    LogItem.index_name = "api-umbrella-logs-write-2015-01"

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-03-08",
        :end_at => "2015-03-08",
        :interval => "hour",
        :prefix => "0/",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_operator(data["results"].length, :>, 0)
    assert_equal(2, data["results"][0]["hits"])
    assert_equal("Sun, Mar 8, 2015 12:00am MST", data["hits_over_time"]["rows"][0]["c"][0]["f"])
    assert_equal(1425798000000, data["hits_over_time"]["rows"][0]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"]["rows"][0]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"]["rows"][0]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015 1:00am MST", data["hits_over_time"]["rows"][1]["c"][0]["f"])
    assert_equal(1425801600000, data["hits_over_time"]["rows"][1]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][1]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][1]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015 3:00am MDT", data["hits_over_time"]["rows"][2]["c"][0]["f"])
    assert_equal(1425805200000, data["hits_over_time"]["rows"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][2]["c"][1]["v"])
    assert_equal("Sun, Mar 8, 2015 4:00am MDT", data["hits_over_time"]["rows"][3]["c"][0]["f"])
    assert_equal(1425808800000, data["hits_over_time"]["rows"][3]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"]["rows"][3]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"]["rows"][3]["c"][1]["v"])
  end

  def test_bins_daily_results_daylight_saving_time_end
    LogItem.index_name = "api-umbrella-logs-write-2014-11"
    Time.use_zone("UTC") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T00:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T08:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T09:00:00"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-03T10:00:00"))
    end
    LogItem.gateway.refresh_index!
    LogItem.index_name = "api-umbrella-logs-write-2015-01"

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2014-11-01",
        :end_at => "2014-11-03",
        :interval => "day",
        :prefix => "0/",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_operator(data["results"].length, :>, 0)
    assert_equal(4, data["results"][0]["hits"])
    assert_equal("Sat, Nov 1, 2014", data["hits_over_time"]["rows"][0]["c"][0]["f"])
    assert_equal(1414821600000, data["hits_over_time"]["rows"][0]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][0]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][0]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014", data["hits_over_time"]["rows"][1]["c"][0]["f"])
    assert_equal(1414908000000, data["hits_over_time"]["rows"][1]["c"][0]["v"])
    assert_equal("2", data["hits_over_time"]["rows"][1]["c"][1]["f"])
    assert_equal(2, data["hits_over_time"]["rows"][1]["c"][1]["v"])
    assert_equal("Mon, Nov 3, 2014", data["hits_over_time"]["rows"][2]["c"][0]["f"])
    assert_equal(1414998000000, data["hits_over_time"]["rows"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][2]["c"][1]["v"])
  end

  def test_bins_hourly_results_daylight_saving_time_end
    LogItem.index_name = "api-umbrella-logs-write-2014-11"
    Time.use_zone("UTC") do
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T08:59:59"))
      FactoryBot.create(:log_item, :request_at => Time.zone.parse("2014-11-02T09:00:00"))
    end
    LogItem.gateway.refresh_index!
    LogItem.index_name = "api-umbrella-logs-write-2015-01"

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => "",
        :start_at => "2014-11-02",
        :end_at => "2014-11-02",
        :interval => "hour",
        :prefix => "0/",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_operator(data["results"].length, :>, 0)
    assert_equal(2, data["results"][0]["hits"])
    assert_equal("Sun, Nov 2, 2014 1:00am MDT", data["hits_over_time"]["rows"][1]["c"][0]["f"])
    assert_equal(1414911600000, data["hits_over_time"]["rows"][1]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"]["rows"][1]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"]["rows"][1]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014 1:00am MST", data["hits_over_time"]["rows"][2]["c"][0]["f"])
    assert_equal(1414915200000, data["hits_over_time"]["rows"][2]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][2]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][2]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014 2:00am MST", data["hits_over_time"]["rows"][3]["c"][0]["f"])
    assert_equal(1414918800000, data["hits_over_time"]["rows"][3]["c"][0]["v"])
    assert_equal("1", data["hits_over_time"]["rows"][3]["c"][1]["f"])
    assert_equal(1, data["hits_over_time"]["rows"][3]["c"][1]["v"])
    assert_equal("Sun, Nov 2, 2014 3:00am MST", data["hits_over_time"]["rows"][4]["c"][0]["f"])
    assert_equal(1414922400000, data["hits_over_time"]["rows"][4]["c"][0]["v"])
    assert_equal("0", data["hits_over_time"]["rows"][4]["c"][1]["f"])
    assert_equal(0, data["hits_over_time"]["rows"][4]["c"][1]["v"])
  end
end
