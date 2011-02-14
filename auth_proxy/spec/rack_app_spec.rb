require "spec_helper"
require "auth_proxy/rack_app"

describe AuthProxy::RackApp do
  describe "redis_cache" do
    it "should be a Redis instance" do
      AuthProxy::RackApp.redis_cache.should be_instance_of(Redis)
    end

    it "should be a singleton" do
      AuthProxy::RackApp.redis_cache.should equal(AuthProxy::RackApp.redis_cache)
    end
  end

  describe "instance" do
    it "should look like a Rack application" do
      AuthProxy::RackApp.instance.should respond_to(:call)
    end

    it "first middleware layer should be an instance of Rack::AuthProxy::Log" do
      AuthProxy::RackApp.instance.should be_instance_of(Rack::AuthProxy::Log)
    end

    it "should be a singleton" do
      AuthProxy::RackApp.instance.should equal(AuthProxy::RackApp.instance)
    end
  end

  describe "middleware layer interactions" do
    include Rack::Test::Methods

    def app
      AuthProxy::RackApp.instance
    end

    describe "any request" do
      it "should be logged" do
        get "/api/log_test.xml"

        log = ApiRequestLog.where(:path => "/api/log_test.xml").first

        log.api_key.should == nil
        log.ip_address.should == "127.0.0.1"
        log.response_status.should == 403
      end
    end

    describe "a valid request" do
      it "should return a 200 OK response" do
        api_user = Factory.create(:api_user)
        get "/api/foo.xml?api_key=#{api_user.api_key}"

        last_response.status.should == 200
        last_response.body.should == "OK"
      end
    end

    describe "an unauthenticated request" do
      it "should return a forbidden error with no api_key" do
        get "/api/foo.xml"

        last_response.status.should == 403
        last_response.body.should include("<error>No api_key was supplied")
      end

      it "should return a forbidden error with an invalid api_key" do
        get "/api/foo.xml?api_key=INVALID_KEY"

        last_response.status.should == 403
        last_response.body.should include("<error>An invalid api_key")
      end
    end

    describe "an unauthorized request" do
      it "should deny access for geocoding services to unauthorized users" do
        api_user = Factory.create(:api_user)
        get "/api/geocode.json?api_key=#{api_user.api_key}"

        last_response.status.should == 403
        last_response.body.should include('"errors":["The api_key supplied is not authorized')
      end

      it "should allow access for geocoding services to authorized users" do
        api_user = Factory.create(:api_user, :roles => ["geocode"])
        get "/api/geocode.json?api_key=#{api_user.api_key}"

        last_response.status.should == 200
        last_response.body.should == "OK"
      end
    end
  end
end
