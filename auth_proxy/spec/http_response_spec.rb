require "spec_helper"
require "auth_proxy/http_response"

describe AuthProxy::HttpResponse do
  before(:each) do
    @status = 200
    @headers = { "Content-Type" => "text/plain" }
    @response = ["Body message"]

    @http_response = AuthProxy::HttpResponse.new(@status, @headers, @response)
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
      @http_response.headers["Server"] = "AuthProxy"

      @http_response.headers_output.should include("Server: AuthProxy")
    end
  end

  describe "#to_s" do
    it "outputs the entire response as a string" do
      @http_response.to_s.should == "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nBody message"
    end
  end
end
