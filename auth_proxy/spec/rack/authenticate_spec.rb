require "spec_helper"
require "rack/auth_proxy/authenticate"

describe Rack::AuthProxy::Authenticate do
  include Rack::Test::Methods

  def target_app
    @target_app_called = false
    @target_app_content = "Authenticated content"

    lambda { |env|
      @target_app_called = true
      [200, {}, @target_app_content]
    }
  end

  def app
    Rack::AuthProxy::Authenticate.new(target_app)
  end

  describe "no api_key supplied" do
    it "should not call the target app" do
      get "/test.xml"
      @target_app_called.should == false
    end

    it "should return a forbidden message" do
      get "/test.xml"

      last_response.status.should == 403
      last_response.body.should include("<error>No api_key was supplied.")
    end
  end

  describe "invalid api_key supplied" do
    it "should not call the target app" do
      get "/test.xml?api_key=INVALID_KEY"
      @target_app_called.should == false
    end

    it "should return a forbidden message" do
      get "/test.json?api_key=INVALID_KEY"

      last_response.status.should == 403
      last_response.body.should include('"errors":["An invalid api_key was supplied.')
    end
  end

  describe "disabled api_key supplied" do
    before(:all) do
      @api_user = Factory.create(:disabled_api_user)
    end

    it "should not call the target app" do
      get "/test.xml?api_key=#{@api_user.api_key}"
      @target_app_called.should == false
    end

    it "should return a forbidden message" do
      get "/test.xml?api_key=#{@api_user.api_key}"

      last_response.status.should == 403
      last_response.body.should include("<error>The api_key supplied has been disabled.")
    end
  end

  describe "valid api_key supplied" do
    before(:all) do
      @api_user = Factory.create(:api_user)
    end

    it "should call the target app" do
      get "/test.xml?api_key=#{@api_user.api_key}"
      @target_app_called.should == true
    end

    it "should look for the api_key as a GET parameter" do
      get "/test.xml?api_key=#{@api_user.api_key}"
      last_response.body.should == @target_app_content
    end

    it "should also look for the api_key inside basic HTTP authentication" do
      authorize @api_user.api_key, ""
      get "/test.xml"
      last_response.body.should == @target_app_content
    end

    it "should prefer the api_key in the GET parameter over basic HTTP authentication" do
      authorize "INVALID_KEY", ""
      get "/test.xml?api_key=#{@api_user.api_key}"
      last_response.body.should == @target_app_content
    end
  end
end
