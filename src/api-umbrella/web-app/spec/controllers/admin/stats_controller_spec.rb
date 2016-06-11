require 'spec_helper'
require 'test_helper/elasticsearch_helper'

describe Admin::StatsController do
  login_admin

  before(:each) do
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
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

      get :search, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2015-03-07",
        :end_at => "2015-03-09",
        :interval => "day",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["stats"]["total_hits"].should eql(4)
      data["hits_over_time"][0]["c"][0]["f"].should eql("Sat, Mar 7, 2015")
      data["hits_over_time"][0]["c"][0]["v"].should eql(1425711600000)
      data["hits_over_time"][0]["c"][1]["f"].should eql("1")
      data["hits_over_time"][0]["c"][1]["v"].should eql(1)
      data["hits_over_time"][1]["c"][0]["f"].should eql("Sun, Mar 8, 2015")
      data["hits_over_time"][1]["c"][0]["v"].should eql(1425798000000)
      data["hits_over_time"][1]["c"][1]["f"].should eql("2")
      data["hits_over_time"][1]["c"][1]["v"].should eql(2)
      data["hits_over_time"][2]["c"][0]["f"].should eql("Mon, Mar 9, 2015")
      data["hits_over_time"][2]["c"][0]["v"].should eql(1425880800000)
      data["hits_over_time"][2]["c"][1]["f"].should eql("1")
      data["hits_over_time"][2]["c"][1]["v"].should eql(1)
    end

    it "bins the hourly results properly when daylight savings time begins" do
      LogItem.index_name = "api-umbrella-logs-write-2015-03"
      Time.use_zone("UTC") do
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T08:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2015-03-08T09:00:00"))
      end
      LogItem.gateway.refresh_index!
      LogItem.index_name = "api-umbrella-logs-write-2015-01"

      get :search, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2015-03-08",
        :end_at => "2015-03-08",
        :interval => "hour",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["stats"]["total_hits"].should eql(2)
      data["hits_over_time"][0]["c"][0]["f"].should eql("Sun, Mar 8, 2015 12:00am MST")
      data["hits_over_time"][0]["c"][0]["v"].should eql(1425798000000)
      data["hits_over_time"][0]["c"][1]["f"].should eql("0")
      data["hits_over_time"][0]["c"][1]["v"].should eql(0)
      data["hits_over_time"][1]["c"][0]["f"].should eql("Sun, Mar 8, 2015 1:00am MST")
      data["hits_over_time"][1]["c"][0]["v"].should eql(1425801600000)
      data["hits_over_time"][1]["c"][1]["f"].should eql("1")
      data["hits_over_time"][1]["c"][1]["v"].should eql(1)
      data["hits_over_time"][2]["c"][0]["f"].should eql("Sun, Mar 8, 2015 3:00am MDT")
      data["hits_over_time"][2]["c"][0]["v"].should eql(1425805200000)
      data["hits_over_time"][2]["c"][1]["f"].should eql("1")
      data["hits_over_time"][2]["c"][1]["v"].should eql(1)
      data["hits_over_time"][3]["c"][0]["f"].should eql("Sun, Mar 8, 2015 4:00am MDT")
      data["hits_over_time"][3]["c"][0]["v"].should eql(1425808800000)
      data["hits_over_time"][3]["c"][1]["f"].should eql("0")
      data["hits_over_time"][3]["c"][1]["v"].should eql(0)
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

      get :search, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2014-11-01",
        :end_at => "2014-11-03",
        :interval => "day",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["stats"]["total_hits"].should eql(4)
      data["hits_over_time"][0]["c"][0]["f"].should eql("Sat, Nov 1, 2014")
      data["hits_over_time"][0]["c"][0]["v"].should eql(1414821600000)
      data["hits_over_time"][0]["c"][1]["f"].should eql("1")
      data["hits_over_time"][0]["c"][1]["v"].should eql(1)
      data["hits_over_time"][1]["c"][0]["f"].should eql("Sun, Nov 2, 2014")
      data["hits_over_time"][1]["c"][0]["v"].should eql(1414908000000)
      data["hits_over_time"][1]["c"][1]["f"].should eql("2")
      data["hits_over_time"][1]["c"][1]["v"].should eql(2)
      data["hits_over_time"][2]["c"][0]["f"].should eql("Mon, Nov 3, 2014")
      data["hits_over_time"][2]["c"][0]["v"].should eql(1414998000000)
      data["hits_over_time"][2]["c"][1]["f"].should eql("1")
      data["hits_over_time"][2]["c"][1]["v"].should eql(1)
    end

    it "bins the hourly results properly when daylight savings time ends" do
      LogItem.index_name = "api-umbrella-logs-write-2014-11"
      Time.use_zone("UTC") do
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T08:59:59"))
        FactoryGirl.create(:log_item, :request_at => Time.zone.parse("2014-11-02T09:00:00"))
      end
      LogItem.gateway.refresh_index!
      LogItem.index_name = "api-umbrella-logs-write-2015-01"

      get :search, {
        :format => "json",
        :tz => "America/Denver",
        :search => "",
        :start_at => "2014-11-02",
        :end_at => "2014-11-02",
        :interval => "hour",
      }

      response.status.should eql(200)
      data = MultiJson.load(response.body)
      data["stats"]["total_hits"].should eql(2)
      data["hits_over_time"][1]["c"][0]["f"].should eql("Sun, Nov 2, 2014 1:00am MDT")
      data["hits_over_time"][1]["c"][0]["v"].should eql(1414911600000)
      data["hits_over_time"][1]["c"][1]["f"].should eql("0")
      data["hits_over_time"][1]["c"][1]["v"].should eql(0)
      data["hits_over_time"][2]["c"][0]["f"].should eql("Sun, Nov 2, 2014 1:00am MST")
      data["hits_over_time"][2]["c"][0]["v"].should eql(1414915200000)
      data["hits_over_time"][2]["c"][1]["f"].should eql("1")
      data["hits_over_time"][2]["c"][1]["v"].should eql(1)
      data["hits_over_time"][3]["c"][0]["f"].should eql("Sun, Nov 2, 2014 2:00am MST")
      data["hits_over_time"][3]["c"][0]["v"].should eql(1414918800000)
      data["hits_over_time"][3]["c"][1]["f"].should eql("1")
      data["hits_over_time"][3]["c"][1]["v"].should eql(1)
      data["hits_over_time"][4]["c"][0]["f"].should eql("Sun, Nov 2, 2014 3:00am MST")
      data["hits_over_time"][4]["c"][0]["v"].should eql(1414922400000)
      data["hits_over_time"][4]["c"][1]["f"].should eql("0")
      data["hits_over_time"][4]["c"][1]["v"].should eql(0)
    end
  end

  describe "GET logs" do
    it "strips the api_key from the request_url on the JSON response" do
      FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"), :request_url => "http://127.0.0.1/with_api_key/?foo=bar&api_key=my_secret_key", :request_query => { "foo" => "bar", "api_key" => "my_secret_key" })
      LogItem.gateway.refresh_index!

      get :logs, {
        "format" => "json",
        "tz" => "America/Denver",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "interval" => "day",
        "start" => "0",
        "length" => "10",
      }

      response.status.should eql(200)
      body = response.body
      data = MultiJson.load(body)
      data["recordsTotal"].should eql(1)
      data["data"][0]["request_url"].should eql("/with_api_key/?foo=bar")
      data["data"][0]["request_query"].should eql({ "foo" => "bar" })
      body.should_not include("my_secret_key")
    end

    it "strips the api_key from the request_url on the CSV response" do
      FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"), :request_url => "http://127.0.0.1/with_api_key/?api_key=my_secret_key&foo=bar", :request_query => { "foo" => "bar", "api_key" => "my_secret_key" })
      LogItem.gateway.refresh_index!

      get :logs, {
        "format" => "csv",
        "tz" => "America/Denver",
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "interval" => "day",
        "start" => "0",
        "length" => "10",
      }

      response.status.should eql(200)
      body = response.body
      body.should include(",http://127.0.0.1/with_api_key/?foo=bar,")
      body.should_not include("my_secret_key")
    end

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
      lines[0].should eql("Time,Method,Host,URL,User,IP Address,Country,State,City,Status,Reason Denied,Response Time,Content Type,Accept Encoding,User Agent")
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

      it "operates properly with null operators and a null value" do
        FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"), :request_user_agent => "gatekeeper denied code null test")
        FactoryGirl.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z"), :gatekeeper_denied_code => "api_key_missing", :request_user_agent => "gatekeeper denied code not null test")
        LogItem.gateway.refresh_index!

        get :logs, {
          "format" => "json",
          "tz" => "America/Denver",
          "start_at" => "2015-01-13",
          "end_at" => "2015-01-18",
          "interval" => "day",
          "start" => "0",
          "length" => "10",
          "query" => '{"condition":"AND","rules":[{"id":"gatekeeper_denied_code","field":"gatekeeper_denied_code","type":"string","input":"select","operator":"is_not_null","value":null}]}'
        }

        response.status.should eql(200)
        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"][0]["request_user_agent"].should eql("gatekeeper denied code not null test")
      end
    end
  end
end
