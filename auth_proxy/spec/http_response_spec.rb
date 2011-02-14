require "spec_helper"
require "auth_proxy/http_response"

describe AuthProxy::HttpResponse do
  before(:each) do
    @status = 200
    @headers = { "Content-Type" => "text/plain" }
    @body = "Body message"

    @response = AuthProxy::HttpResponse.new(@status, @headers, @body)
  end

  it "should accept parameters during initialization" do
    @response.status.should == 200
    @response.headers_output.should include("Content-Type: text/plain")
    @response.body.should == "Body message"
  end

  describe "#headers_output" do
    it "doesn't return 'Thin' as the server" do
      @response.headers_output.should_not include("Server: Thin")
    end

    it "still returns custom server headers" do
      @response.headers["Server"] = "AuthProxy"

      @response.headers_output.should include("Server: AuthProxy")
    end
  end

  describe "#to_s" do
    it "outputs the entire response as a string" do
      @response.to_s.should == "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nBody message"
    end
  end
end
