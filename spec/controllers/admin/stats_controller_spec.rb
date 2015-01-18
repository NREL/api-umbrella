require 'spec_helper'

describe Admin::StatsController do
  login_admin

  before(:each) do
    begin
      LogItem.gateway.client.indices.delete :index => LogItem.index_name
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
    end
  end

  describe "GET logs" do
    it "downloads a CSV that requires an elasticsearch scan and scroll query" do
      FactoryGirl.create_list(:log_item, 1005, :request_at => Time.parse("2015-01-16T06:06:28.816Z"))
      LogItem.gateway.refresh_index!

      get :logs, {
        "format" => "csv",
        "tz" => "America/Denver",
        "search" => "",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "interval" => "day",
      }

      response.status.should eql(200)
      response.headers["Content-Type"].should eql("text/csv")
      response.headers["Content-Disposition"].should include("attachment; filename=\"api_logs (#{Time.now.strftime("%b %-e %Y")}).csv\"")

      lines = response.body.split("\n")
      lines[0].should eql("Time,Method,Host,URL,User,IP Address,Country,State,City,Status,Response Time,Content Type,Accept Encoding,User Agent")
      lines.length.should eql(1006)
    end
  end
end
