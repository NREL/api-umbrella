require "spec_helper"

describe ApiUmbrella::Gatekeeper::Server do
  describe "authorization" do
    describe "unauthorized api_key with no roles" do
      before(:all) do
        @api_user = FactoryGirl.create(:api_user)
      end

      it "doesn't call the target app" do
        make_request(:get, "/api/geocode?api_key=#{@api_user.api_key}")
        @backend_called.should eq(false)
      end

      it "returns a forbidden message" do
        make_request(:get, "/api/geocode?api_key=#{@api_user.api_key}")

        @last_header.status.should eq(403)
        @last_response.should include("The api_key supplied is not authorized")
      end
    end

    describe "unauthorized api_key with other roles" do
      before(:all) do
        @api_user = FactoryGirl.create(:api_user, :roles => ["something", "else"])
      end

      it "doesn't call the target app" do
        make_request(:get, "/api/geocode?api_key=#{@api_user.api_key}")
        @backend_called.should eq(false)
      end

      it "returns a forbidden message" do
        make_request(:get, "/api/geocode?api_key=#{@api_user.api_key}")

        @last_header.status.should eq(403)
        @last_response.should include("The api_key supplied is not authorized")
      end
    end

    describe "authorized api_key with the appropriate role" do
      before(:all) do
        @api_user = FactoryGirl.create(:api_user, :roles => ["geocode"])
      end

      it "calls the target app" do
        make_request(:get, "/api/geocode?api_key=#{@api_user.api_key}")
        @backend_called.should eq(true)
        @last_response.should eq("Private Geocoding")
      end
    end
  end
end
