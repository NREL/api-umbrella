require "spec_helper"
require "rack/auth_proxy/formatted_error"

describe Rack::AuthProxy::FormattedError do
  include Rack::Test::Methods

  def app
    @original_error_status = 500
    @original_error_headers = {}
    @original_error_message = "Error content"

    lambda { |env| [@original_error_status, @original_error_headers, @original_error_message] }
  end

  def formatted_error_response
    Rack::AuthProxy::FormattedError.response(last_request.env, last_response.status, last_response.headers, last_response.body)
  end

  it "should default to XML errors" do
    get "/test"

    formatted_status, formatted_headers, formatted_body = formatted_error_response
    xml = Nokogiri::XML.parse(formatted_body)

    formatted_status.should == @original_error_status
    formatted_headers["Content-Type"].should == "application/xml"
    xml.xpath("/errors/error").first.content.should == @original_error_message
  end

  it "should use the path extension to detect and return XML errors" do
    get "/test.xml"

    formatted_status, formatted_headers, formatted_body = formatted_error_response
    xml = Nokogiri::XML.parse(formatted_body)

    formatted_status.should == @original_error_status
    formatted_headers["Content-Type"].should == "application/xml"
    xml.xpath("/errors/error").first.content.should == @original_error_message
  end

  it "should fallback to the 'format' GET attribute to detect and return XML errors" do
    get "/test?format=xml"

    formatted_status, formatted_headers, formatted_body = formatted_error_response
    xml = Nokogiri::XML.parse(formatted_body)

    formatted_status.should == @original_error_status
    formatted_headers["Content-Type"].should == "application/xml"
    xml.xpath("/errors/error").first.content.should == @original_error_message
  end

  it "should prefer the path extension detection over the GET attribute" do
    get "/test.xml?format=json"

    formatted_status, formatted_headers, formatted_body = formatted_error_response
    xml = Nokogiri::XML.parse(formatted_body)

    formatted_status.should == @original_error_status
    formatted_headers["Content-Type"].should == "application/xml"
    xml.xpath("/errors/error").first.content.should == @original_error_message
  end

  it "should use the path extension to detect and return JSON errors" do
    get "/test.json"

    formatted_status, formatted_headers, formatted_body = formatted_error_response
    json = Yajl::Parser.parse(formatted_body)

    formatted_status.should == @original_error_status
    formatted_headers["Content-Type"].should == "application/json"
    json["errors"].first.should == @original_error_message
  end

  it "should fallback to the 'format' GET attribute to detect and return JSON errors" do
    get "/test?format=json"

    formatted_status, formatted_headers, formatted_body = formatted_error_response
    json = Yajl::Parser.parse(formatted_body)

    formatted_status.should == @original_error_status
    formatted_headers["Content-Type"].should == "application/json"
    json["errors"].first.should == @original_error_message
  end

  it "should use the path extension to detect and return CSV errors" do
    get "/test.csv"

    formatted_status, formatted_headers, formatted_body = formatted_error_response

    formatted_status.should == @original_error_status
    formatted_headers["Content-Type"].should == "text/csv"
    formatted_body.should == "Error\n#{@original_error_message}"
  end

  it "should fallback to the 'format' GET attribute to detect and return CSV errors" do
    get "/test?format=csv"

    formatted_status, formatted_headers, formatted_body = formatted_error_response

    formatted_status.should == @original_error_status
    formatted_headers["Content-Type"].should == "text/csv"
    formatted_body.should == "Error\n#{@original_error_message}"
  end

  it "should fall back to plain text error messages for unknown content types" do
    get "/test.foobar"

    formatted_status, formatted_headers, formatted_body = formatted_error_response

    formatted_status.should == @original_error_status
    formatted_headers["Content-Type"].should == "text/plain"
    formatted_body.should == "Error: #{@original_error_message}"
  end
end
