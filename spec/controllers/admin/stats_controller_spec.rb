require 'spec_helper'

describe Admin::StatsController do
  login_admin

  before(:each) do
    LogItem.gateway.client.delete_by_query :index => LogItem.index_name, :body => {
      :query => {
        :match_all => {},
      },
    }
  end

  describe "GET search" do
    it "bins the results by day with proper time zone" do
      Time.use_zone("America/Denver") do
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-12T23:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-13T00:00:00"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-18T23:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-19T00:00:00"))
      end
      LogItem.gateway.refresh_index!

      get :search, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["stats"]["total_hits"].should eql(2)
      data["hits_over_time"][0]["c"][0]["f"].should eql("Tue, Jan 13, 2015")
      data["hits_over_time"][0]["c"][0]["v"].should eql(1421132400000)
      data["hits_over_time"][0]["c"][1]["f"].should eql("1")
      data["hits_over_time"][0]["c"][1]["v"].should eql(1)
      data["hits_over_time"][5]["c"][0]["f"].should eql("Sun, Jan 18, 2015")
      data["hits_over_time"][5]["c"][0]["v"].should eql(1421564400000)
      data["hits_over_time"][5]["c"][1]["f"].should eql("1")
      data["hits_over_time"][5]["c"][1]["v"].should eql(1)
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

    describe "query builder" do
      it "searches fields case-insensitively by default" do
        FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"), :request_user_agent => "MOZILLAAA")
        LogItem.gateway.refresh_index!

        get :logs, {
          "format" => "json",
          "tz" => "America/Denver",
          "start_at" => "2015-01-13",
          "end_at" => "2015-01-18",
          "interval" => "day",
          "start" => "0",
          "length" => "10",
          "query" => '{"condition":"AND","rules":[{"id":"request_user_agent","field":"request_user_agent","type":"string","input":"text","operator":"begins_with","value":"Mozilla"}]}'
        }

        response.status.should eql(200)
        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"][0]["request_user_agent"].should eql("MOZILLAAA")
      end

      it "matches the api key case-sensitively" do
        FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"), :api_key => "AbCDeF", :request_user_agent => "api key match test")
        LogItem.gateway.refresh_index!

        get :logs, {
          "format" => "json",
          "tz" => "America/Denver",
          "start_at" => "2015-01-13",
          "end_at" => "2015-01-18",
          "interval" => "day",
          "start" => "0",
          "length" => "10",
          "query" => '{"condition":"AND","rules":[{"id":"api_key","field":"api_key","type":"string","input":"text","operator":"begins_with","value":"AbCDeF"}]}'
        }

        response.status.should eql(200)
        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"][0]["request_user_agent"].should eql("api key match test")
      end
    end
  end
end
