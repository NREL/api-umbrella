require "spec_helper"

describe ApiUmbrella::Gatekeeper::HttpResponse do
  before(:each) do
    @status = 200
    @headers = { "Content-Type" => "text/plain" }
    @response = ["Body message"]

    @http_response = ApiUmbrella::Gatekeeper::HttpResponse.new
    @http_response.status = @status
    @http_response.headers = @headers
    @http_response.body = @response
  end

  it "inherits from Thin::Response" do
    @http_response.should be_kind_of(Thin::Response)
  end

  it "should accept parameters during initialization" do
    @http_response.status.should == 200
    @http_response.headers_output.should include("Content-Type: text/plain")
    @http_response.body.should == ["Body message"]
  end

  describe "#headers_output" do
    it "doesn't return 'Thin' as the server" do
      @http_response.headers_output.should_not include("Server: Thin")
    end

    it "still returns custom server headers" do
      @http_response.headers["Server"] = "ApiUmbrella::Gatekeeper"

      @http_response.headers_output.should include("Server: ApiUmbrella::Gatekeeper")
    end
  end
end
