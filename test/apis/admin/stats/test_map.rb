require_relative "../../../test_helper"

class Test::Apis::Admin::Stats::TestMap < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    LogItem.clean_indices!
  end

  def test_world
    FactoryBot.create_list(:log_item, 2, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CO", :request_ip_city => "Golden")
    FactoryBot.create_list(:log_item, 1, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "CA", :request_ip_region => "ON", :request_ip_city => "Toronto")
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "world",
      },
    }))

    assert_response_code(200, response)
    body = response.body
    data = MultiJson.load(body)
    assert_equal({
      "map_breadcrumbs" => [],
      "map_regions" => [
        { "c" => [{ "v" => "US", "f" => "United States of America" }, { "v" => 2, "f" => "2" }] },
        { "c" => [{ "v" => "CA", "f" => "Canada" }, { "v" => 1, "f" => "1" }] },
      ],
      "region_field" => "request_ip_country",
      "regions" => [
        { "id" => "US", "name" => "United States of America", "hits" => 2 },
        { "id" => "CA", "name" => "Canada", "hits" => 1 },
      ],
    }, data)
  end

  def test_country_non_us
    FactoryBot.create(:analytics_city, :country => "CA", :region => "ON", :city => "Toronto", :location => [-79.5323, 43.6949])
    FactoryBot.create(:analytics_city, :country => "CA", :region => "QC", :city => "Montréal", :location => [-73.5877, 45.5009])
    FactoryBot.create_list(:log_item, 2, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "CA", :request_ip_region => "ON", :request_ip_city => "Toronto")
    FactoryBot.create_list(:log_item, 1, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "CA", :request_ip_region => "QC", :request_ip_city => "Montréal")
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "CA",
      },
    }))

    assert_response_code(200, response)
    body = response.body
    data = MultiJson.load(body)
    assert_equal({
      "map_breadcrumbs" => [
        { "region" => "world", "name" => "World" },
        { "name" => "Canada" },
      ],
      "map_regions" => [
        { "c" => [{ "v" => 43.6949 }, { "v" => -79.5323 }, { "v" => "Toronto" }, { "v" => 2, "f" => "2" }] },
        { "c" => [{ "v" => 45.5009 }, { "v" => -73.5877 }, { "v" => "Montréal" }, { "v" => 1, "f" => "1" }] },
      ],
      "region_field" => "request_ip_city",
      "regions" => [
        { "id" => "Toronto", "name" => "Toronto", "hits" => 2 },
        { "id" => "Montréal", "name" => "Montréal", "hits" => 1 },
      ],
    }, data)
  end

  def test_country_us
    FactoryBot.create_list(:log_item, 2, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CO", :request_ip_city => "Golden")
    FactoryBot.create_list(:log_item, 1, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CA", :request_ip_city => "San Diego")
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "US",
      },
    }))

    assert_response_code(200, response)
    body = response.body
    data = MultiJson.load(body)
    assert_equal({
      "map_breadcrumbs" => [
        { "region" => "world", "name" => "World" },
        { "name" => "United States of America" },
      ],
      "map_regions" => [
        { "c" => [{ "v" => "CO", "f" => "Colorado" }, { "v" => 2, "f" => "2" }] },
        { "c" => [{ "v" => "CA", "f" => "California" }, { "v" => 1, "f" => "1" }] },
      ],
      "region_field" => "request_ip_region",
      "regions" => [
        { "id" => "US-CO", "name" => "Colorado", "hits" => 2 },
        { "id" => "US-CA", "name" => "California", "hits" => 1 },
      ],
    }, data)
  end

  def test_us_state
    FactoryBot.create(:analytics_city, :country => "US", :region => "CO", :city => "Golden", :location => [-105.2433, 39.7146])
    FactoryBot.create_list(:log_item, 2, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CO", :request_ip_city => "Golden")
    FactoryBot.create_list(:log_item, 1, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CA", :request_ip_city => "San Diego")
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "US-CO",
      },
    }))

    assert_response_code(200, response)
    body = response.body
    data = MultiJson.load(body)
    assert_equal({
      "map_breadcrumbs" => [
        { "region" => "world", "name" => "World" },
        { "region" => "US", "name" => "United States of America" },
        { "name" => "Colorado" },
      ],
      "map_regions" => [
        { "c" => [{ "v" => 39.7146 }, { "v" => -105.2433 }, { "v" => "Golden" }, { "v" => 2, "f" => "2" }] },
      ],
      "region_field" => "request_ip_city",
      "regions" => [
        { "id" => "Golden", "name" => "Golden", "hits" => 2 },
      ],
    }, data)
  end

  def test_csv_download
    FactoryBot.create_list(:log_item, 2, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CO", :request_ip_city => "Golden")
    FactoryBot.create_list(:log_item, 1, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "CA", :request_ip_region => "ON", :request_ip_city => "Toronto")
    LogItem.refresh_indices!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.csv", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "world",
      },
    }))

    assert_response_code(200, response)
    assert_equal("text/csv", response.headers["Content-Type"])
    assert_match("attachment; filename=\"api_map_#{Time.now.utc.strftime("%Y-%m-%d")}.csv\"", response.headers["Content-Disposition"])

    csv = CSV.parse(response.body)
    assert_equal(3, csv.length, csv)
    assert_equal(["Location", "Hits"], csv[0])
    assert_equal(["United States of America", "2"], csv[1])
    assert_equal(["Canada", "1"], csv[2])
  end

  def test_no_results_non_existent_indices
    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "start_at" => "2000-01-13",
        "end_at" => "2000-01-18",
        "region" => "world",
      },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "map_breadcrumbs" => [],
      "map_regions" => [],
      "region_field" => "request_ip_country",
      "regions" => [],
    }, data)
  end
end
