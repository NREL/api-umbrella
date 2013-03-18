require "spec_helper"

describe ApiUmbrella::Gatekeeper::Server do
  describe "authentication" do
    describe "no api_key supplied" do
      it "doesn't call the target app" do
        make_request(:get, "/hello")
        @backend_called.should eq(false)
      end

      it "returns a forbidden message" do
        make_request(:get, "/hello")

        @last_header.status.should eq(403)
        @last_response.should include("No api_key was supplied.")
      end
    end

    describe "empty api_key supplied" do
      it "doesn't call the target app" do
        make_request(:get, "/hello?api_query=")
        @backend_called.should eq(false)
      end

      it "returns a forbidden message" do
        make_request(:get, "/hello?api_key=")

        @last_header.status.should eq(403)
        @last_response.should include("No api_key was supplied.")
      end
    end

    describe "invalid api_key supplied" do
      it "doesn't call the target app" do
        make_request(:get, "/hello?api_key=invalid")
        @backend_called.should eq(false)
      end

      it "returns a forbidden message" do
        make_request(:get, "/hello?api_key=invalid")

        @last_header.status.should eq(403)
        @last_response.should include("An invalid api_key was supplied.")
      end
    end

    describe "disabled api_key supplied" do
      before(:all) do
        @api_user = FactoryGirl.create(:disabled_api_user)
      end

      it "doesn't call the target app" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")
        @backend_called.should eq(false)
      end

      it "returns a forbidden message" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")

        @last_header.status.should eq(403)
        @last_response.should include("The api_key supplied has been disabled.")
      end
    end

    describe "valid api_key supplied" do
      before(:all) do
        @api_user = FactoryGirl.create(:api_user)
      end

      it "calls the target app" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")
        @backend_called.should eq(true)
        @last_response.should eq("Hello World")
      end

      it "looks for the api_key as a GET parameter" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")
        @last_response.should eq("Hello World")
      end

      it "also looks for the api_key inside basic HTTP authentication" do
        make_request(:get, "/hello", :head => { :authorization => [@api_user.api_key, ""] })
        @last_response.should eq("Hello World")
      end

      it "prefers the api_key in the GET parameter over basic HTTP authentication" do
        make_request(:get, "/hello", :head => { :authorization => ["invalid", ""] }, :query => { :api_key => @api_user.api_key })
        @last_response.should eq("Hello World")
      end
    end
  end
end
