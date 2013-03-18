require "spec_helper"

describe ApiUmbrella::Gatekeeper::Server do
  describe "throttling" do
    before(:all) do
    end

    describe "hourly limit" do
      it "allows up to the hourly limit of requests" do
        api_user = FactoryGirl.create(:api_user)

        Timecop.freeze do
          make_multiple_requests(50, :get, "/hello?api_key=#{api_user.api_key}")
          @last_header.status.should == 200
          @last_response.should eq("Hello World")
        end
      end

      it "rejects requests after the hourly limit has been exceeded" do
        api_user = FactoryGirl.create(:api_user)

        Timecop.freeze do
          make_multiple_requests(51, :get, "/hello?api_key=#{api_user.api_key}")
          @last_header.status.should == 429
          @last_response.should include("Rate Limit Exceeded")
        end
      end

      it "allows requests again in the next hour after the rate limit has been exceeded" do
        api_user = FactoryGirl.create(:api_user)
        start_time = Date.today.to_time

        Timecop.freeze(start_time) do
          make_multiple_requests(51, :get, "/hello?api_key=#{api_user.api_key}")
        end

        Timecop.freeze(start_time + 1.hour) do
          make_request(:get, "/hello?api_key=#{api_user.api_key}")
          @last_header.status.should == 200
          @last_response.should eq("Hello World")
        end
      end
    end

    describe "daily limit" do
      it "allows up to the daily limit of requests" do
        api_user = FactoryGirl.create(:api_user)
        start_time = Date.today.to_time

        Timecop.freeze(start_time) do
          make_multiple_requests(50, :get, "/hello?api_key=#{api_user.api_key}")
        end

        Timecop.freeze(start_time + 1.hour) do
          make_multiple_requests(10, :get, "/hello?api_key=#{api_user.api_key}")
          @last_header.status.should == 200
          @last_response.should eq("Hello World")
        end
      end

      it "rejects requests after the daily limit has been exceeded" do
        api_user = FactoryGirl.create(:api_user)
        start_time = Date.today.to_time

        Timecop.freeze(start_time) do
          make_multiple_requests(50, :get, "/hello?api_key=#{api_user.api_key}")
        end

        Timecop.freeze(start_time + 1.hour) do
          make_multiple_requests(11, :get, "/hello?api_key=#{api_user.api_key}")
          @last_header.status.should == 429
          @last_response.should include("Rate Limit Exceeded")
        end
      end

      it "allows requests again in the next day after the rate limit has been exceeded" do
        api_user = FactoryGirl.create(:api_user)
        start_time = Date.today.to_time

        Timecop.freeze(start_time) do
          make_multiple_requests(50, :get, "/hello?api_key=#{api_user.api_key}")
        end

        Timecop.freeze(start_time + 1.hour) do
          make_multiple_requests(11, :get, "/hello?api_key=#{api_user.api_key}")
        end

        Timecop.freeze(start_time + 1.day) do
          make_multiple_requests(11, :get, "/hello?api_key=#{api_user.api_key}")
          make_request(:get, "/hello?api_key=#{api_user.api_key}")
          @last_header.status.should == 200
          @last_response.should eq("Hello World")
        end
      end
    end
  end
end
