require "spec_helper"
require "rack/auth_proxy/authorize"

describe Rack::AuthProxy::Authorize do
  include Rack::Test::Methods

  def target_app
    @target_app_called = false
    @target_app_status = 200
    @target_app_headers = {}
    @target_app_content = "Authorized content"

    lambda { |env|
      @target_app_called = true
      [@target_app_status, @target_app_headers, [@target_app_content]]
    }
  end

  def app
    Rack::AuthProxy::Authorize.new(target_app)
  end

  it "should allow access to services by default" do
    api_user = FactoryGirl.create(:api_user)
    get "/api/foo.xml?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

    @target_app_called.should == true
    last_response.status.should == @target_app_status
    last_response.body.should == @target_app_content
  end

  describe "VIBE services" do
    it "should deny access by default" do
      api_user = FactoryGirl.create(:api_user)
      get "/api/afdc_laws.xml?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

      @target_app_called.should == false
      last_response.status.should == 403
      last_response.body.should include("The api_key supplied is not authorized to access the given service.")
    end

    it "should grant access to users with the 'vibe' role" do
      api_user = FactoryGirl.create(:api_user, :roles => ["vibe"])
      get "/api/afdc_laws.xml?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

      @target_app_called.should == true
      last_response.status.should == @target_app_status
      last_response.body.should == @target_app_content
    end
  end

  describe "geocoding services" do
    it "should deny access by default" do
      api_user = FactoryGirl.create(:api_user)
      get "/api/geocode.json?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

      @target_app_called.should == false
      last_response.status.should == 403
      last_response.body.should include("The api_key supplied is not authorized to access the given service.")
    end

    it "should deny access to users with non-authorized roles" do
      api_user = FactoryGirl.create(:api_user, :roles => ["vibe", "vin", "foo", "bar"])
      get "/api/geocode.xml?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

      @target_app_called.should == false
      last_response.status.should == 403
      last_response.body.should include("The api_key supplied is not authorized to access the given service.")
    end

    it "should grant access to users with the 'geocode' role" do
      api_user = FactoryGirl.create(:api_user, :roles => ["geocode"])
      get "/api/geocode.xml?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

      @target_app_called.should == true
      last_response.status.should == @target_app_status
      last_response.body.should == @target_app_content
    end
  end

  describe "VIN services" do
    it "should deny access by default" do
      api_user = FactoryGirl.create(:api_user)
      get "/api/vin.xml?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

      @target_app_called.should == false
      last_response.status.should == 403
      last_response.body.should include("The api_key supplied is not authorized to access the given service.")
    end

    it "should grant access to users with the 'vin' role" do
      api_user = FactoryGirl.create(:api_user, :roles => ["vin"])
      get "/api/vin.xml?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

      @target_app_called.should == true
      last_response.status.should == @target_app_status
      last_response.body.should == @target_app_content
    end
  end

  describe "API user services" do
    it "should deny access by default" do
      api_user = FactoryGirl.create(:api_user)
      post "/api/api-user.xml?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

      @target_app_called.should == false
      last_response.status.should == 403
      last_response.body.should include("The api_key supplied is not authorized to access the given service.")
    end

    it "should grant access to users with the 'api_user_creation' role" do
      api_user = FactoryGirl.create(:api_user, :roles => ["api_user_creation"])
      post "/api/api-user.xml?api_key=#{api_user.api_key}", {}, "rack.api_user" => api_user

      @target_app_called.should == true
      last_response.status.should == @target_app_status
      last_response.body.should == @target_app_content
    end
  end
end
