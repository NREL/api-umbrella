require_relative "../test_helper"

class TestAdminUiStatsLogs < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTests::AdminAuth
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
  end

  def test_xss_escaping_in_table
    log = FactoryGirl.create(:xss_log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_method => "OPTIONS")
    LogItem.gateway.refresh_index!

    admin_login
    visit "/admin/#/stats/logs?tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")

    assert_text(log.request_method)
    assert_text(log.request_accept_encoding)
    assert_text(log.request_ip_city)
    assert_text(log.request_ip_country)
    assert_text(log.request_ip_region)
    assert_text(log.request_user_agent)
    assert_text(log.response_content_type)
    assert_text(log.user_email)
    refute_selector(".xss-test", :visible => :all)
  end

  def test_csv_download_link_changes_with_filters
    FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc)
    LogItem.gateway.refresh_index!
    default_query = JSON.generate({
      "condition" => "AND",
      "rules" => [{
        "field" => "gatekeeper_denied_code",
        "id" => "gatekeeper_denied_code",
        "input" => "select",
        "operator" => "is_null",
        "type" => "string",
        "value" => nil,
      }],
    })

    admin_login
    visit "/admin/#/stats/logs?tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /start_at=2015-01-12/)
    link = find_link("Download CSV")
    uri = Addressable::URI.parse(link[:href])
    assert_equal("/admin/stats/logs.csv", uri.path)
    assert_equal({
      "tz" => "America/Denver",
      "search" => "",
      "start_at" => "2015-01-12",
      "end_at" => "2015-01-18",
      "interval" => "day",
      "query" => default_query,
      "beta_analytics" => "false",
    }, uri.query_values)

    visit "/admin/#/stats/logs?tz=America%2FDenver&search=&start_at=2015-01-13&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /start_at=2015-01-13/)
    link = find_link("Download CSV")
    uri = Addressable::URI.parse(link[:href])
    assert_equal("/admin/stats/logs.csv", uri.path)
    assert_equal({
      "tz" => "America/Denver",
      "search" => "",
      "start_at" => "2015-01-13",
      "end_at" => "2015-01-18",
      "interval" => "day",
      "query" => default_query,
      "beta_analytics" => "false",
    }, uri.query_values)

    visit "/admin/#/stats/logs?tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /start_at=2015-01-12/)
    assert_link("Download CSV", :href => /%22rules%22%3A%5B%7B/)
    click_button "Delete" # Remove the initial filter
    click_button "Filter"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /%22rules%22%3A%5B%5D%7D/)
    link = find_link("Download CSV")
    uri = Addressable::URI.parse(link[:href])
    assert_equal("/admin/stats/logs.csv", uri.path)
    assert_equal({
      "tz" => "America/Denver",
      "start_at" => "2015-01-12",
      "end_at" => "2015-01-18",
      "interval" => "day",
      "query" => JSON.generate({ "condition" => "AND", "rules" => [] }),
      "search" => "",
      "beta_analytics" => "false",
    }, uri.query_values)

    visit "/admin/#/stats/logs?tz=America%2FDenver&search=&start_at=2015-01-13&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /start_at=2015-01-13/)
    find("a", :text => /Switch to advanced filters/).click
    fill_in "search", :with => "response_status:200"
    click_button "Filter"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /response_status%3A200/)
    link = find_link("Download CSV")
    uri = Addressable::URI.parse(link[:href])
    assert_equal("/admin/stats/logs.csv", uri.path)
    assert_equal({
      "tz" => "America/Denver",
      "search" => "response_status:200",
      "start_at" => "2015-01-13",
      "end_at" => "2015-01-18",
      "interval" => "day",
      "query" => "",
      "beta_analytics" => "false",
    }, uri.query_values)
  end

  def test_csv_download
    FactoryGirl.create_list(:log_item, 5, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_method => "OPTIONS")
    FactoryGirl.create_list(:log_item, 5, :request_at => 1421413588000, :request_method => "OPTIONS")
    LogItem.gateway.refresh_index!

    admin_login
    visit "/admin/#/stats/logs?tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")

    # Wait for the ajax actions to fetch the graph and tables to both
    # complete, or else the download link seems to be flakey in Capybara.
    assert_text("Download CSV")
    assert_text("OPTIONS")
    refute_selector(".busy-blocker")
    click_link "Download CSV"

    # Downloading files via Capybara generally seems flakey, so add an extra
    # wait.
    Timeout.timeout(Capybara.default_max_wait_time) do
      while(page.response_headers["Content-Type"] != "text/csv")
        sleep(0.1)
      end
    end
    assert_equal(200, page.status_code)
    assert_equal("text/csv", page.response_headers["Content-Type"])
  end

  def test_does_not_show_beta_analytics_toggle_by_default
    admin_login
    visit "/admin/#/stats/logs?tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    assert_text("view top users")
    refute_text("Beta Analytics")
  end

  def test_shows_beta_analytics_toggle_when_enabled
    override_config({ "analytics" => { "outputs" => ["kylin"] } }, "--router") do
      admin_login
      visit "/admin/#/stats/logs?tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
      assert_text("view top users")
      assert_text("Beta Analytics")
    end
  end
end
