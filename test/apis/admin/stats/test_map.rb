require_relative "../../../test_helper"

class TestAdminStatsMap < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
  end

  def test_world
    FactoryGirl.create_list(:log_item, 2, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CO", :request_ip_city => "Golden")
    FactoryGirl.create_list(:log_item, 1, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "CA", :request_ip_region => "ON", :request_ip_city => "Toronto")
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "tz" => "America/Denver",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "world",
      },
    }))

    assert_equal(200, response.code, response.body)
    body = response.body
    data = MultiJson.load(body)
    assert_equal({
      "map_breadcrumbs" => [],
      "map_regions" => [
        { "c" => [{ "v" => "US", "f" => "United States" }, { "v" => 2, "f" => "2" }] },
        { "c" => [{ "v" => "CA", "f" => "Canada" }, { "v" => 1, "f" => "1" }] },
      ],
      "region_field" => "request_ip_country",
      "regions" => [
        { "id" => "US", "name" => "United States", "hits" => 2 },
        { "id" => "CA", "name" => "Canada", "hits" => 1 },
      ],
    }, data)
  end

  def test_country_non_us
    FactoryGirl.create(:log_city_location, :country => "CA", :region => "ON", :city => "Toronto", :location => { :type => "Point", :coordinates => [-79.5323, 43.6949] })
    FactoryGirl.create(:log_city_location, :country => "CA", :region => "QC", :city => "Montréal", :location => { :type => "Point", :coordinates => [-73.5877, 45.5009] })
    FactoryGirl.create_list(:log_item, 2, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "CA", :request_ip_region => "ON", :request_ip_city => "Toronto")
    FactoryGirl.create_list(:log_item, 1, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "CA", :request_ip_region => "QC", :request_ip_city => "Montréal")
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "tz" => "America/Denver",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "CA",
      },
    }))

    assert_equal(200, response.code, response.body)
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
    FactoryGirl.create_list(:log_item, 2, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CO", :request_ip_city => "Golden")
    FactoryGirl.create_list(:log_item, 1, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CA", :request_ip_city => "San Diego")
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "tz" => "America/Denver",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "US",
      },
    }))

    assert_equal(200, response.code, response.body)
    body = response.body
    data = MultiJson.load(body)
    assert_equal({
      "map_breadcrumbs" => [
        { "region" => "world", "name" => "World" },
        { "name" => "United States" },
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
    FactoryGirl.create(:log_city_location, :country => "US", :region => "CO", :city => "Golden", :location => { :type => "Point", :coordinates => [-105.2433, 39.7146] })
    FactoryGirl.create_list(:log_item, 2, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CO", :request_ip_city => "Golden")
    FactoryGirl.create_list(:log_item, 1, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_ip_country => "US", :request_ip_region => "CA", :request_ip_city => "San Diego")
    LogItem.gateway.refresh_index!

    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/map.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "tz" => "America/Denver",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "region" => "US-CO",
      },
    }))

    assert_equal(200, response.code, response.body)
    body = response.body
    data = MultiJson.load(body)
    assert_equal({
      "map_breadcrumbs" => [
        { "region" => "world", "name" => "World" },
        { "region" => "US", "name" => "United States" },
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
end
