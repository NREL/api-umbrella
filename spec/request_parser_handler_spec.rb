# encoding: utf-8

require "api-umbrella-gatekeeper/connection_handler"
require "api-umbrella-gatekeeper/request_parser_handler"

describe ApiUmbrella::Gatekeeper::RequestParserHandler do
  before(:each) do
    @connection_handler = ApiUmbrella::Gatekeeper::ConnectionHandler.new(nil)
    @handler = ApiUmbrella::Gatekeeper::RequestParserHandler.new(@connection_handler)
  end

  describe "on_headers_complete" do
    it "notifies the connection handler when headers have been parsed" do
      headers = { "Host" => "localhost", "Accept" => "*/*" }
      @connection_handler.should_receive(:request_headers_parsed).with(headers)
      @handler.on_headers_complete(headers)
    end
  end

  describe "on_body" do
    it "increments the connection handler's request body size" do
      @handler.on_body("Hello")
      @connection_handler.request_body_size.should == 5
    end

    it "increments the connection handler's request body size on multiple calls" do
      @handler.on_body("Hello")
      @handler.on_body("Goodbye")
      @connection_handler.request_body_size.should == 12
    end

    it "increments the connection handler's request body size by bytesize" do
      @handler.on_body("Résumé")
      @connection_handler.request_body_size.should == 8
    end
  end
end
