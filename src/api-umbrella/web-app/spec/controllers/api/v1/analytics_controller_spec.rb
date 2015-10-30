require 'spec_helper'

describe Api::V1::AnalyticsController do
  login_admin

  before(:each) do
    ["2014-11", "2015-01", "2015-03"].each do |month|
      LogItem.gateway.client.delete_by_query :index => "api-umbrella-logs-#{month}", :body => {
        :query => {
          :match_all => {},
        },
      }
    end
  end

  describe "GET drilldown" do
    it "bins the results by day with proper time zone" do
      Time.use_zone("America/Denver") do
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-12T23:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-13T00:00:00"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-18T23:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-01-19T00:00:00"))
      end
      LogItem.gateway.refresh_index!

      get :drilldown, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
        :prefix => "0/",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["results"][0]["hits"].should eql(2)
      data["hits_over_time"]["rows"][0]["c"][0]["f"].should eql("Tue, Jan 13, 2015")
      data["hits_over_time"]["rows"][0]["c"][0]["v"].should eql(1421132400000)
      data["hits_over_time"]["rows"][0]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][0]["c"][1]["v"].should eql(1)
      data["hits_over_time"]["rows"][5]["c"][0]["f"].should eql("Sun, Jan 18, 2015")
      data["hits_over_time"]["rows"][5]["c"][0]["v"].should eql(1421564400000)
      data["hits_over_time"]["rows"][5]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][5]["c"][1]["v"].should eql(1)
    end

    it "bins the daily results properly when daylight savings time begins" do
      LogItem.index_name = "api-umbrella-logs-write-2015-03"
      Time.use_zone("UTC") do
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T00:00:00"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T08:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T09:00:00"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-09T10:00:00"))
      end
      LogItem.gateway.refresh_index!
      LogItem.index_name = "api-umbrella-logs-write-2015-01"

      get :drilldown, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2015-03-07",
        :end_at => "2015-03-09",
        :interval => "day",
        :prefix => "0/",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["results"][0]["hits"].should eql(4)
      data["hits_over_time"]["rows"][0]["c"][0]["f"].should eql("Sat, Mar 7, 2015")
      data["hits_over_time"]["rows"][0]["c"][0]["v"].should eql(1425711600000)
      data["hits_over_time"]["rows"][0]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][0]["c"][1]["v"].should eql(1)
      data["hits_over_time"]["rows"][1]["c"][0]["f"].should eql("Sun, Mar 8, 2015")
      data["hits_over_time"]["rows"][1]["c"][0]["v"].should eql(1425798000000)
      data["hits_over_time"]["rows"][1]["c"][1]["f"].should eql("2")
      data["hits_over_time"]["rows"][1]["c"][1]["v"].should eql(2)
      data["hits_over_time"]["rows"][2]["c"][0]["f"].should eql("Mon, Mar 9, 2015")
      data["hits_over_time"]["rows"][2]["c"][0]["v"].should eql(1425880800000)
      data["hits_over_time"]["rows"][2]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][2]["c"][1]["v"].should eql(1)
    end

    it "bins the hourly results properly when daylight savings time begins" do
      LogItem.index_name = "api-umbrella-logs-write-2015-03"
      Time.use_zone("UTC") do
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T08:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T09:00:00"))
      end
      LogItem.gateway.refresh_index!
      LogItem.index_name = "api-umbrella-logs-write-2015-01"

      get :drilldown, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2015-03-08",
        :end_at => "2015-03-08",
        :interval => "hour",
        :prefix => "0/",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["results"][0]["hits"].should eql(2)
      data["hits_over_time"]["rows"][0]["c"][0]["f"].should eql("Sun, Mar 8, 2015 12:00am MST")
      data["hits_over_time"]["rows"][0]["c"][0]["v"].should eql(1425798000000)
      data["hits_over_time"]["rows"][0]["c"][1]["f"].should eql("0")
      data["hits_over_time"]["rows"][0]["c"][1]["v"].should eql(0)
      data["hits_over_time"]["rows"][1]["c"][0]["f"].should eql("Sun, Mar 8, 2015 1:00am MST")
      data["hits_over_time"]["rows"][1]["c"][0]["v"].should eql(1425801600000)
      data["hits_over_time"]["rows"][1]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][1]["c"][1]["v"].should eql(1)
      data["hits_over_time"]["rows"][2]["c"][0]["f"].should eql("Sun, Mar 8, 2015 3:00am MDT")
      data["hits_over_time"]["rows"][2]["c"][0]["v"].should eql(1425805200000)
      data["hits_over_time"]["rows"][2]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][2]["c"][1]["v"].should eql(1)
      data["hits_over_time"]["rows"][3]["c"][0]["f"].should eql("Sun, Mar 8, 2015 4:00am MDT")
      data["hits_over_time"]["rows"][3]["c"][0]["v"].should eql(1425808800000)
      data["hits_over_time"]["rows"][3]["c"][1]["f"].should eql("0")
      data["hits_over_time"]["rows"][3]["c"][1]["v"].should eql(0)
    end

    it "bins the daily results properly when daylight savings time ends" do
      LogItem.index_name = "api-umbrella-logs-write-2014-11"
      Time.use_zone("UTC") do
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T00:00:00"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T08:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T09:00:00"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-03T10:00:00"))
      end
      LogItem.gateway.refresh_index!
      LogItem.index_name = "api-umbrella-logs-write-2015-01"

      get :drilldown, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2014-11-01",
        :end_at => "2014-11-03",
        :interval => "day",
        :prefix => "0/",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["results"][0]["hits"].should eql(4)
      data["hits_over_time"]["rows"][0]["c"][0]["f"].should eql("Sat, Nov 1, 2014")
      data["hits_over_time"]["rows"][0]["c"][0]["v"].should eql(1414821600000)
      data["hits_over_time"]["rows"][0]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][0]["c"][1]["v"].should eql(1)
      data["hits_over_time"]["rows"][1]["c"][0]["f"].should eql("Sun, Nov 2, 2014")
      data["hits_over_time"]["rows"][1]["c"][0]["v"].should eql(1414908000000)
      data["hits_over_time"]["rows"][1]["c"][1]["f"].should eql("2")
      data["hits_over_time"]["rows"][1]["c"][1]["v"].should eql(2)
      data["hits_over_time"]["rows"][2]["c"][0]["f"].should eql("Mon, Nov 3, 2014")
      data["hits_over_time"]["rows"][2]["c"][0]["v"].should eql(1414998000000)
      data["hits_over_time"]["rows"][2]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][2]["c"][1]["v"].should eql(1)
    end

    it "bins the hourly results properly when daylight savings time ends" do
      LogItem.index_name = "api-umbrella-logs-write-2014-11"
      Time.use_zone("UTC") do
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T08:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T09:00:00"))
      end
      LogItem.gateway.refresh_index!
      LogItem.index_name = "api-umbrella-logs-write-2015-01"

      get :drilldown, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2014-11-02",
        :end_at => "2014-11-02",
        :interval => "hour",
        :prefix => "0/",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["results"][0]["hits"].should eql(2)
      data["hits_over_time"]["rows"][1]["c"][0]["f"].should eql("Sun, Nov 2, 2014 1:00am MDT")
      data["hits_over_time"]["rows"][1]["c"][0]["v"].should eql(1414911600000)
      data["hits_over_time"]["rows"][1]["c"][1]["f"].should eql("0")
      data["hits_over_time"]["rows"][1]["c"][1]["v"].should eql(0)
      data["hits_over_time"]["rows"][2]["c"][0]["f"].should eql("Sun, Nov 2, 2014 1:00am MST")
      data["hits_over_time"]["rows"][2]["c"][0]["v"].should eql(1414915200000)
      data["hits_over_time"]["rows"][2]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][2]["c"][1]["v"].should eql(1)
      data["hits_over_time"]["rows"][3]["c"][0]["f"].should eql("Sun, Nov 2, 2014 2:00am MST")
      data["hits_over_time"]["rows"][3]["c"][0]["v"].should eql(1414918800000)
      data["hits_over_time"]["rows"][3]["c"][1]["f"].should eql("1")
      data["hits_over_time"]["rows"][3]["c"][1]["v"].should eql(1)
      data["hits_over_time"]["rows"][4]["c"][0]["f"].should eql("Sun, Nov 2, 2014 3:00am MST")
      data["hits_over_time"]["rows"][4]["c"][0]["v"].should eql(1414922400000)
      data["hits_over_time"]["rows"][4]["c"][1]["f"].should eql("0")
      data["hits_over_time"]["rows"][4]["c"][1]["v"].should eql(0)
    end
  end
end
