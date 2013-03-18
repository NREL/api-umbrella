require "spec_helper"

describe ApiUmbrella::Gatekeeper::Server do
  describe "proxy behavior" do
    CRLF = "\r\n"

    before(:all) do
      @api_user = FactoryGirl.create(:api_user)
    end

    before(:each) do
      ApiUmbrella::ApiRequestLog.delete_all
    end

    it "correctly sends the request body when it's split between chunks" do
      send_chunks([
        "POST /echo?api_key=#{@api_user.api_key} HTTP/1.1#{CRLF}",
        "Content-Length: 12#{CRLF}#{CRLF}Hello",
        "Goodbye",
      ])

      @last_response.should eq("HelloGoodbye")
    end
  end
end
