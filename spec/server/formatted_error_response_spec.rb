require "spec_helper"

describe ApiUmbrella::Gatekeeper::Server do
  describe "formatted error responses" do
    it "defaults to plain text errors" do
      make_request(:get, "/hello")

      @last_header["Content-Type"].should eq("text/plain")
      @last_response.should match(/^Error: No api_key was supplied./)
    end

    it "includes the Content-Length header" do
      make_request(:get, "/hello")

      @last_header["Content-Length"].should eq("69")
    end

    it "doesn't include a server name header" do
      make_request(:get, "/hello")

      @last_header["Server"].should eq(nil)
    end

    context "using the path extension to detect and return formatted errors" do
      it "handles xml" do
        make_request(:get, "/hello.xml")

        @last_header["Content-Type"].should eq("application/xml")
        xml = Nokogiri::XML.parse(@last_response)
        xml.xpath("/errors/error").first.content.should match(/^No api_key was supplied./)
      end

      it "handle json" do
        make_request(:get, "/hello.json")

        @last_header["Content-Type"].should eq("application/json")
        json = Yajl::Parser.parse(@last_response)
        json["errors"].first.should match(/^No api_key was supplied./)
      end

      it "handles csv" do
        make_request(:get, "/hello.csv")

        @last_header["Content-Type"].should eq("text/csv")
        @last_response.should match(/^Error\nNo api_key was supplied./)
      end

      it "falls back to plain text error messages for unknown content types" do
        make_request(:get, "/hello.foobar")

        @last_header["Content-Type"].should eq("text/plain")
        @last_response.should match(/^Error: No api_key was supplied./)
      end

      it "handles formats case insensitively" do
        make_request(:get, "/hello.JSoN")

        @last_header["Content-Type"].should eq("application/json")
        json = Yajl::Parser.parse(@last_response)
        json["errors"].first.should match(/^No api_key was supplied./)
      end
    end

    context "using the 'format' GET param to detect and return formatted errors" do
      it "detects the format from the GET param" do
        make_request(:get, "/hello?format=json")

        @last_header["Content-Type"].should eq("application/json")
        json = Yajl::Parser.parse(@last_response)
        json["errors"].first.should match(/^No api_key was supplied./)
      end

      it "prefers the path extension detection over the GET param" do
        make_request(:get, "/hello.json?format=xml")

        @last_header["Content-Type"].should eq("application/json")
        json = Yajl::Parser.parse(@last_response)
        json["errors"].first.should match(/^No api_key was supplied./)
      end
    end
  end
end
