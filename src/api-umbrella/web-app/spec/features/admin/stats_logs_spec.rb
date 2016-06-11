require "spec_helper"
require "addressable/uri"
require 'test_helper/elasticsearch_helper'

describe "analytics filter logs", :js => true do
  login_admin

  before(:each) do
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
  end

  describe "xss" do
    it "escapes html entities in the table" do
      log = FactoryGirl.create(:xss_log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"), :request_method => "OPTIONS")
      LogItem.gateway.refresh_index!

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"

      page.should have_content(log.request_method)
      page.should have_content(log.request_accept_encoding)
      page.should have_content(log.request_ip_city)
      page.should have_content(log.request_ip_country)
      page.should have_content(log.request_ip_region)
      page.should have_content(log.request_user_agent)
      page.should have_content(log.response_content_type)
      page.should have_content(log.user_email)
      page.should_not have_selector(".xss-test", :visible => :all)
    end
  end

  describe "csv download" do
    it "updates the download link as the query parameters change" do
      FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"))
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
        }]
      })

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
      wait_for_loading_spinners
      page.should have_link("Download CSV", :href => /start_at=2015-01-12/)
      link = find_link("Download CSV")
      uri = Addressable::URI.parse(link[:href])
      uri.path.should eql("/admin/stats/logs.csv")
      uri.query_values.should eql({
        "tz" => "America/Denver",
        "search" => "",
        "start_at" => "2015-01-12",
        "end_at" => "2015-01-18",
        "interval" => "day",
        "query" => default_query,
        "beta_analytics" => "false",
      })

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-13&end_at=2015-01-18&interval=day"
      wait_for_loading_spinners
      page.should have_link("Download CSV", :href => /start_at=2015-01-13/)
      link = find_link("Download CSV")
      uri = Addressable::URI.parse(link[:href])
      uri.path.should eql("/admin/stats/logs.csv")
      uri.query_values.should eql({
        "tz" => "America/Denver",
        "search" => "",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "interval" => "day",
        "query" => default_query,
        "beta_analytics" => "false",
      })

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
      wait_for_loading_spinners
      page.should have_link("Download CSV", :href => /start_at=2015-01-12/)
      page.should have_link("Download CSV", :href => /%22rules%22%3A%5B%7B/)
      click_button "Delete"   # Remove the initial filter
      click_button "Filter"
      wait_for_loading_spinners
      page.should have_link("Download CSV", :href => /%22rules%22%3A%5B%5D%7D/)
      link = find_link("Download CSV")
      uri = Addressable::URI.parse(link[:href])
      uri.path.should eql("/admin/stats/logs.csv")
      uri.query_values.should eql({
        "tz" => "America/Denver",
        "start_at" => "2015-01-12",
        "end_at" => "2015-01-18",
        "interval" => "day",
        "query" => JSON.generate({ "condition" => "AND", "rules" => [] }),
        "search" => "",
        "beta_analytics" => "false",
      })

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-13&end_at=2015-01-18&interval=day"
      wait_for_loading_spinners
      page.should have_link("Download CSV", :href => /start_at=2015-01-13/)
      find("a", :text => /Switch to advanced filters/).click
      fill_in "search", :with => "response_status:200"
      click_button "Filter"
      wait_for_loading_spinners
      page.should have_link("Download CSV", :href => /response_status%3A200/)
      link = find_link("Download CSV")
      uri = Addressable::URI.parse(link[:href])
      uri.path.should eql("/admin/stats/logs.csv")
      uri.query_values.should eql({
        "tz" => "America/Denver",
        "search" => "response_status:200",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "interval" => "day",
        "query" => "",
        "beta_analytics" => "false",
      })
    end

    it "successfully downloads a csv" do
      FactoryGirl.create_list(:log_item, 5, :request_at => Time.parse("2015-01-16T06:06:28.816Z"), :request_method => "OPTIONS")
      FactoryGirl.create_list(:log_item, 5, :request_at => 1421413588000, :request_method => "OPTIONS")
      LogItem.gateway.refresh_index!

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
      wait_for_loading_spinners

      # Wait for the ajax actions to fetch the graph and tables to both
      # complete, or else the download link seems to be flakey in Capybara.
      page.should have_content("Download CSV")
      page.should have_content("OPTIONS")
      wait_for_ajax
      click_link "Download CSV"

      # Downloading files via Capybara generally seems flakey, so add an extra
      # wait.
      wait_until { page.response_headers["Content-Type"] == "text/csv" }
      page.status_code.should eql(200)
      page.response_headers["Content-Type"].should eql("text/csv")
    end
  end
end
