require "spec_helper"
require "rack/auth_proxy/formatted_error_response"

describe Rack::AuthProxy::FormattedErrorResponse do
  include Rack::Test::Methods

  describe "application error" do
    def target_app
      @target_app_status = 500
      @target_app_headers = {}
      @target_app_content = "Error content"

      lambda { |env| [@target_app_status, @target_app_headers, [@target_app_content]] }
    end

    def app
      Rack::AuthProxy::FormattedErrorResponse.new(target_app)
    end

    it "should default to XML errors" do
      get "/test"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "application/xml"
      xml = Nokogiri::XML.parse(last_response.body)
      xml.xpath("/errors/error").first.content.should == @target_app_content
    end

    it "should use the path extension to detect and return XML errors" do
      get "/test.xml"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "application/xml"
      xml = Nokogiri::XML.parse(last_response.body)
      xml.xpath("/errors/error").first.content.should == @target_app_content
    end

    it "should fallback to the 'format' GET attribute to detect and return XML errors" do
      get "/test?format=xml"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "application/xml"
      xml = Nokogiri::XML.parse(last_response.body)
      xml.xpath("/errors/error").first.content.should == @target_app_content
    end

    it "should prefer the path extension detection over the GET attribute" do
      get "/test.xml?format=json"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "application/xml"
      xml = Nokogiri::XML.parse(last_response.body)
      xml.xpath("/errors/error").first.content.should == @target_app_content
    end

    it "should use the path extension to detect and return JSON errors" do
      get "/test.json"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "application/json"
      json = Yajl::Parser.parse(last_response.body)
      json["errors"].first.should == @target_app_content
    end

    it "should fallback to the 'format' GET attribute to detect and return JSON errors" do
      get "/test?format=json"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "application/json"
      json = Yajl::Parser.parse(last_response.body)
      json["errors"].first.should == @target_app_content
    end

    it "should use the path extension to detect and return CSV errors" do
      get "/test.csv"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "text/csv"
      last_response.body.should == "Error\n#{@target_app_content}"
    end

    it "should fallback to the 'format' GET attribute to detect and return CSV errors" do
      get "/test?format=csv"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "text/csv"
      last_response.body.should == "Error\n#{@target_app_content}"
    end

    it "should fall back to plain text error messages for unknown content types" do
      get "/test.foobar"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "text/plain"
      last_response.body.should == "Error: #{@target_app_content}"
    end
  end

  describe "application error as string" do
    def target_app
      @target_app_status = 500
      @target_app_headers = {}
      @target_app_content = "Error content"

      lambda { |env| [@target_app_status, @target_app_headers, @target_app_content] }
    end

    def app
      Rack::AuthProxy::FormattedErrorResponse.new(target_app)
    end

    it "should format the error message desipte the invalid/string-based rack response" do
      get "/test?format=json"

      last_response.status.should == @target_app_status
      last_response.headers["Content-Type"].should == "application/json"
      json = Yajl::Parser.parse(last_response.body)
      json["errors"].first.should == @target_app_content
    end

  end

  describe "application success" do
    def target_app
      @target_app_status = 200
      @target_app_headers = {}
      @target_app_content = "Response content"

      lambda { |env| [@target_app_status, @target_app_headers, [@target_app_content]] }
    end

    def app
      Rack::AuthProxy::FormattedErrorResponse.new(target_app)
    end

    it "should pass through the successful response" do
      get "/test.json"

      last_response.status.should == @target_app_status
      last_response.headers.should == @target_app_headers
      last_response.body.should == @target_app_content
    end
  end
end
