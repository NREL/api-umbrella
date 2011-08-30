require "spec_helper"
require "rack/auth_proxy/log"


describe Rack::AuthProxy::Log do
  include Rack::Test::Methods

  def target_app
    @target_app_status = 200
    @target_app_headers = { "Content-Type"=>"text/plain", "Content-Length"=>"16" }
    @target_app_content = "Response content"

    lambda { |env| [@target_app_status, @target_app_headers, [@target_app_content]] }
  end

  def app
    Rack::AuthProxy::Log.new(target_app)
  end

  before(:each) do
    @api_key = Factory.next(:api_key)
  end

  it "should log the details for a request" do
    Timecop.freeze do
      get "/api/foo.xml?api_key=#{@api_key}&foo=bar", {}, "rack.api_key" => @api_key

      log = ApiRequestLog.where(:path => "/api/foo.xml").last

      log.api_key.should == @api_key
      log.ip_address.should == "127.0.0.1"
      log.requested_at.should == Time.now.utc
      log.response_status.should == @target_app_status
      log.response_error.should == nil
    end
  end

  it "should log the details for unauthenticated requests" do
    Timecop.freeze do
      get "/api/unauth.xml?foo=bar"

      log = ApiRequestLog.where(:path => "/api/unauth.xml").last

      log.api_key.should == nil
      log.ip_address.should == "127.0.0.1"
      log.requested_at.should == Time.now.utc
      log.response_status.should == @target_app_status
      log.response_error.should == nil
    end
  end

  it "should serialize and log the rack environment" do
    post "/api/bar.xml?api_key=#{@api_key}&foo=bar", {}, "rack.api_key" => @api_key

    log = ApiRequestLog.where(:path => "/api/bar.xml").last

    env = Yajl::Parser.parse(log.env)
    request = Rack::Request.new(env)

    request.path.should == "/api/bar.xml"
    request.content_type.should == "application/x-www-form-urlencoded"
    request.GET["api_key"].should == @api_key
    request.GET["foo"].should == "bar"
  end

  it "should pass through the response" do
    get "/api/foo.xml?api_key=#{@api_key}&foo=bar", {}, "rack.api_key" => @api_key

    last_response.status.should == @target_app_status
    last_response.headers.should == @target_app_headers
    last_response.body.should == @target_app_content
  end

  describe "error responses" do
    def target_error_app
      @target_error_app_status = 500
      @target_error_app_headers = {}
      @target_error_app_content = "Error message"

      lambda { |env| [@target_error_app_status, @target_error_app_headers, [@target_error_app_content]] }
    end

    def app
      Rack::AuthProxy::Log.new(target_error_app)
    end

    it "should log the response body for errors" do
      get "/api/moo.xml?api_key=#{@api_key}", {}, "rack.api_key" => @api_key

      log = ApiRequestLog.where(:path => "/api/moo.xml").last

      log.api_key.should == @api_key
      log.response_status.should == @target_error_app_status
      log.response_error.should == @target_error_app_content
    end
  end
end
