require "spec_helper"
require "addressable/uri"

describe "apis", :js => true do
  login_admin

  before(:each) do
    begin
      LogItem.gateway.client.indices.delete :index => LogItem.index_name
    rescue Elasticsearch::Transport::Transport::Errors::NotFound # rubocop:disable Lint/HandleExceptions
    end
  end

  describe "xss" do
    it "escapes html entities in the table" do
      log = FactoryGirl.create(:xss_log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"), :request_method => "OPTIONS")
      LogItem.gateway.refresh_index!

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"

      page.should have_content(log.request_method)
      page.should_not have_selector(".xss-test", :visible => :all)
      page.should have_content(log.request_accept_encoding)
      page.should have_content(log.request_ip_city)
      page.should have_content(log.request_ip_country)
      page.should have_content(log.request_ip_region)
      page.should have_content(log.request_user_agent)
      page.should have_content(log.response_content_type)
      page.should have_content(log.user_email)
    end
  end

  describe "csv download" do
    it "updates the download link as the query parameters change" do
      FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"))
      LogItem.gateway.refresh_index!

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
      link = find_link("Download CSV")
      uri = Addressable::URI.parse(link[:href])
      uri.path.should eql("/admin/stats/logs.csv")
      uri.query_values.should eql({
        "tz" => "America/Denver",
        "search" => "",
        "start_at" => "2015-01-12",
        "end_at" => "2015-01-18",
        "interval" => "day",
      })

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-13&end_at=2015-01-18&interval=day"
      link = find_link("Download CSV")
      uri = Addressable::URI.parse(link[:href])
      uri.path.should eql("/admin/stats/logs.csv")
      uri.query_values.should eql({
        "tz" => "America/Denver",
        "search" => "",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "interval" => "day",
      })

      find("a", :text => /Filter Results/).click
      find("a", :text => /Switch to advanced filters/).click
      fill_in "search", :with => "response_status:200"
      click_button "Filter"
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
      })
    end

    it "successfully downloads a csv" do
      FactoryGirl.create_list(:log_item, 10, :request_at => Time.parse("2015-01-16T06:06:28.816Z"))
      LogItem.gateway.refresh_index!

      visit "/admin/#/stats/logs/tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
      click_link "Download CSV"
      page.status_code.should eql(200)
      page.response_headers["Content-Type"].should eql("text/csv")
    end
  end
end
