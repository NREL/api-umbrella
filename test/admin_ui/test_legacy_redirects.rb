require_relative "../test_helper"

class Test::AdminUi::TestLegacyRedirects < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server

    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
    FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc)
    LogItem.gateway.refresh_index!
  end

  def test_drilldown
    admin_login
    visit "/admin/#/stats/drilldown/tz=America%2FDenver&search=&start_at=2015-01-15&end_at=2015-01-18&query=%7B%22condition%22%3A%22AND%22%2C%22rules%22%3A%5B%7B%22id%22%3A%22gatekeeper_denied_code%22%2C%22field%22%3A%22gatekeeper_denied_code%22%2C%22type%22%3A%22string%22%2C%22input%22%3A%22select%22%2C%22operator%22%3A%22is_null%22%2C%22value%22%3Anull%7D%2C%7B%22id%22%3A%22request_host%22%2C%22field%22%3A%22request_host%22%2C%22type%22%3A%22string%22%2C%22input%22%3A%22text%22%2C%22operator%22%3A%22begins_with%22%2C%22value%22%3A%22example.com%22%7D%5D%7D&interval=hour&beta_analytics=false&region=US"
    assert_link("Download CSV", :href => /start_at=2015-01-15/)

    uri = Addressable::URI.parse(page.current_url)
    assert_equal("/admin/", uri.path)
    assert(uri.fragment)

    fragment_uri = Addressable::URI.parse(uri.fragment)
    assert_equal("/stats/drilldown", fragment_uri.path)
    assert_equal({
      "start_at" => "2015-01-15",
      "end_at" => "2015-01-18",
      "interval" => "hour",
      "query" => "{\"condition\":\"AND\",\"rules\":[{\"id\":\"gatekeeper_denied_code\",\"field\":\"gatekeeper_denied_code\",\"type\":\"string\",\"input\":\"select\",\"operator\":\"is_null\",\"value\":null},{\"id\":\"request_host\",\"field\":\"request_host\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"begins_with\",\"value\":\"example.com\"}]}",
      "tz" => "America/Denver",
    }, fragment_uri.query_values)
  end

  def test_logs
    admin_login
    visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-15&end_at=2015-01-18&query=%7B%22condition%22%3A%22AND%22%2C%22rules%22%3A%5B%7B%22id%22%3A%22gatekeeper_denied_code%22%2C%22field%22%3A%22gatekeeper_denied_code%22%2C%22type%22%3A%22string%22%2C%22input%22%3A%22select%22%2C%22operator%22%3A%22is_null%22%2C%22value%22%3Anull%7D%2C%7B%22id%22%3A%22request_host%22%2C%22field%22%3A%22request_host%22%2C%22type%22%3A%22string%22%2C%22input%22%3A%22text%22%2C%22operator%22%3A%22begins_with%22%2C%22value%22%3A%22example.com%22%7D%5D%7D&interval=hour&beta_analytics=false&region=US"
    assert_link("Download CSV", :href => /start_at=2015-01-15/)

    uri = Addressable::URI.parse(page.current_url)
    assert_equal("/admin/", uri.path)
    assert(uri.fragment)

    fragment_uri = Addressable::URI.parse(uri.fragment)
    assert_equal("/stats/logs", fragment_uri.path)
    assert_equal({
      "start_at" => "2015-01-15",
      "end_at" => "2015-01-18",
      "interval" => "hour",
      "query" => "{\"condition\":\"AND\",\"rules\":[{\"id\":\"gatekeeper_denied_code\",\"field\":\"gatekeeper_denied_code\",\"type\":\"string\",\"input\":\"select\",\"operator\":\"is_null\",\"value\":null},{\"id\":\"request_host\",\"field\":\"request_host\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"begins_with\",\"value\":\"example.com\"}]}",
      "tz" => "America/Denver",
    }, fragment_uri.query_values)
  end

  def test_users
    admin_login
    visit "/admin/#/stats/users/tz=America%2FDenver&search=&start_at=2015-01-15&end_at=2015-01-18&query=%7B%22condition%22%3A%22AND%22%2C%22rules%22%3A%5B%7B%22id%22%3A%22gatekeeper_denied_code%22%2C%22field%22%3A%22gatekeeper_denied_code%22%2C%22type%22%3A%22string%22%2C%22input%22%3A%22select%22%2C%22operator%22%3A%22is_null%22%2C%22value%22%3Anull%7D%2C%7B%22id%22%3A%22request_host%22%2C%22field%22%3A%22request_host%22%2C%22type%22%3A%22string%22%2C%22input%22%3A%22text%22%2C%22operator%22%3A%22begins_with%22%2C%22value%22%3A%22example.com%22%7D%5D%7D&interval=hour&beta_analytics=false&region=US"
    assert_link("Download CSV", :href => /start_at=2015-01-15/)

    uri = Addressable::URI.parse(page.current_url)
    assert_equal("/admin/", uri.path)
    assert(uri.fragment)

    fragment_uri = Addressable::URI.parse(uri.fragment)
    assert_equal("/stats/users", fragment_uri.path)
    assert_equal({
      "start_at" => "2015-01-15",
      "end_at" => "2015-01-18",
      "query" => "{\"condition\":\"AND\",\"rules\":[{\"id\":\"gatekeeper_denied_code\",\"field\":\"gatekeeper_denied_code\",\"type\":\"string\",\"input\":\"select\",\"operator\":\"is_null\",\"value\":null},{\"id\":\"request_host\",\"field\":\"request_host\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"begins_with\",\"value\":\"example.com\"}]}",
      "tz" => "America/Denver",
    }, fragment_uri.query_values)
  end

  def test_map
    admin_login
    visit "/admin/#/stats/map/tz=America%2FDenver&search=&start_at=2015-01-15&end_at=2015-01-18&query=%7B%22condition%22%3A%22AND%22%2C%22rules%22%3A%5B%7B%22id%22%3A%22gatekeeper_denied_code%22%2C%22field%22%3A%22gatekeeper_denied_code%22%2C%22type%22%3A%22string%22%2C%22input%22%3A%22select%22%2C%22operator%22%3A%22is_null%22%2C%22value%22%3Anull%7D%2C%7B%22id%22%3A%22request_host%22%2C%22field%22%3A%22request_host%22%2C%22type%22%3A%22string%22%2C%22input%22%3A%22text%22%2C%22operator%22%3A%22begins_with%22%2C%22value%22%3A%22example.com%22%7D%5D%7D&interval=hour&beta_analytics=false&region=US"
    assert_link("Download CSV", :href => /start_at=2015-01-15/)

    uri = Addressable::URI.parse(page.current_url)
    assert_equal("/admin/", uri.path)
    assert(uri.fragment)

    fragment_uri = Addressable::URI.parse(uri.fragment)
    assert_equal("/stats/map", fragment_uri.path)
    assert_equal({
      "start_at" => "2015-01-15",
      "end_at" => "2015-01-18",
      "query" => "{\"condition\":\"AND\",\"rules\":[{\"id\":\"gatekeeper_denied_code\",\"field\":\"gatekeeper_denied_code\",\"type\":\"string\",\"input\":\"select\",\"operator\":\"is_null\",\"value\":null},{\"id\":\"request_host\",\"field\":\"request_host\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"begins_with\",\"value\":\"example.com\"}]}",
      "region" => "US",
      "tz" => "America/Denver",
    }, fragment_uri.query_values)
  end
end
