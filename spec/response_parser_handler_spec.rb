# encoding: utf-8

require "auth_proxy/connection_handler"
require "auth_proxy/response_parser_handler"

describe AuthProxy::ResponseParserHandler do
  before(:each) do
    @connection_handler = AuthProxy::ConnectionHandler.new(nil)
    @handler = AuthProxy::ResponseParserHandler.new(@connection_handler)
  end

  describe "on_body" do
    it "increments the connection handler's response body size" do
      @handler.on_body("Hello")
      @connection_handler.response_body_size.should == 5
    end

    it "increments the connection handler's response body size on multiple calls" do
      @handler.on_body("Hello")
      @handler.on_body("Goodbye")
      @connection_handler.response_body_size.should == 12
    end

    it "increments the connection handler's response body size by bytesize" do
      @handler.on_body("Résumé")
      @connection_handler.response_body_size.should == 8
    end
  end
end
