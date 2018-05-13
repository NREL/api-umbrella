require_relative "../test_helper"

class Test::AdminUi::TestStatsDrilldown < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::DateRangePicker
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
  end

  def test_csv_download
    FactoryBot.create_list(:log_item, 5, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc)
    FactoryBot.create_list(:log_item, 5, :request_at => 1421413588000)
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
    visit "/admin/#/stats/drilldown?search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")

    assert_link("Download CSV", :href => /start_at=2015-01-12/)
    link = find_link("Download CSV")
    uri = Addressable::URI.parse(link[:href])
    assert_equal("/api-umbrella/v1/analytics/drilldown.csv", uri.path)
    assert_equal({
      "start_at" => "2015-01-12",
      "end_at" => "2015-01-18",
      "interval" => "day",
      "search" => "",
      "query" => default_query,
      "prefix" => "0/",
    }, uri.query_values.except("api_key"))
    assert_equal(40, uri.query_values["api_key"].length)

    # Wait for the ajax actions to fetch the graph and tables to both
    # complete, or else the download link seems to be flakey in Capybara.
    assert_text("Download CSV")
    assert_text("127.0.0.1/")
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

  def test_date_range_picker
    assert_date_range_picker("/stats/drilldown")
  end
end
