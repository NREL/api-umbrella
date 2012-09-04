# encoding: utf-8

require "timecop"

require "em-proxy"
require "api-umbrella-gatekeeper/connection_handler"

describe ApiUmbrella::Gatekeeper::ConnectionHandler do
  CRLF = "\r\n"

  before(:each) do
    @connection = EventMachine::ProxyServer::Connection.new(:test, {})

    @sent_response = ""
    @connection.stub(:send_data) do |chunk|
      @sent_response << chunk
    end

    @relayed_request = ""
    @connection.stub(:relay_to_servers) do |chunk|
      @relayed_request << chunk
    end

    @connection.stub(:server) {}
    @connection.stub(:close_connection_after_writing) {}

    @handler = ApiUmbrella::Gatekeeper::ConnectionHandler.new(@connection)
  end

  describe "start_time" do
    it "defaults to nil" do
      Timecop.freeze do
        @handler.start_time.should == nil
      end
    end

    it "gets set when the on_data callback gets called" do
      Timecop.freeze do
        @handler.on_data("GET / HTTP/1.1")
        @handler.start_time.should == Time.now
      end
    end

    it "only gets set on the first call to on_data" do
      start_time = Time.local(2008, 9, 1, 12, 0, 0)
      Timecop.freeze(start_time) do
        @handler.on_data("GET / HTTP/1.1#{CRLF}")
        @handler.start_time.should == start_time
      end

      next_time = Time.local(2009, 9, 1, 12, 0, 0)
      Timecop.freeze(next_time) do
        @handler.on_data("User-Agent: curl/7.26.0#{CRLF}")
        @handler.start_time.should_not == next_time
      end
    end
  end

  describe "request_size" do
    it "defaults to 0" do
      @handler.request_size.should == 0
    end

    it "increments when the on_data callback gets called" do
      @handler.on_data("GET / HTTP/1.1#{CRLF}")
      @handler.request_size.should == 16
    end

    it "increments when each time the on_data callback gets called" do
      @handler.on_data("GET / HTTP/1.1#{CRLF}")
      @handler.on_data("User-Agent: curl/7.26.0#{CRLF}")
      @handler.request_size.should == 41
    end

    it "increments by bytesize" do
      @handler.on_data("GET / HTTP/1.1#{CRLF}")
      @handler.on_data("User-Agent: cürl/7.26.0#{CRLF}")
      @handler.request_size.should == 42
    end
  end

  describe "request_body_size" do
    it "is 0 when the headers are being parsed" do
      @handler.on_data("GET / HTTP/1.1#{CRLF}")
      @handler.on_data("Transfer-Encoding: chunked#{CRLF}#{CRLF}")
      @handler.request_body_size.should == 0
    end

    it "increments once the body beings" do
      @handler.on_data("GET / HTTP/1.1#{CRLF}")
      @handler.on_data("Transfer-Encoding: chunked#{CRLF}#{CRLF}")
      @handler.on_data("5#{CRLF}Body #{CRLF}7#{CRLF}Message#{CRLF}0#{CRLF}#{CRLF}")
      @handler.request_body_size.should == 12
    end

    it "increments if the data is spread across " do
      @handler.on_data("GET / HTTP/1.1#{CRLF}")
      @handler.on_data("Transfer-Encoding: chunked#{CRLF}#{CRLF}")
      @handler.on_data("5#{CRLF}Body #{CRLF}7#{CRLF}Message#{CRLF}")
      @handler.on_data("8#{CRLF}Another #{CRLF}7#{CRLF}Message#{CRLF}0#{CRLF}#{CRLF}")
      @handler.request_body_size.should == 27
    end

    it "increments by bytesize" do
      @handler.on_data("GET / HTTP/1.1#{CRLF}")
      @handler.on_data("Transfer-Encoding: chunked#{CRLF}#{CRLF}")
      @handler.on_data("6#{CRLF}Bödy #{CRLF}7#{CRLF}Message#{CRLF}0#{CRLF}#{CRLF}")
      @handler.request_body_size.should == 13
    end
  end

  describe "response_size" do
    it "defaults to 0" do
      @handler.response_size.should == 0
    end

    it "increments when the on_response callback gets called" do
      @handler.on_response(:backend, "HTTP/1.1 200 OK#{CRLF}")
      @handler.response_size.should == 17
    end

    it "increments when each time the on_response callback gets called" do
      @handler.on_response(:backend, "HTTP/1.1 200 OK#{CRLF}")
      @handler.on_response(:backend, "Server: nginx/1.0.0#{CRLF}")
      @handler.response_size.should == 38
    end

    it "increments by bytesize" do
      @handler.on_response(:backend, "HTTP/1.1 200 OK#{CRLF}")
      @handler.on_response(:backend, "Server: ñgiñx/1.0.0#{CRLF}")
      @handler.response_size.should == 40
    end
  end

  describe "response_body_size" do
    it "is 0 when the headers are being parsed" do
      @handler.on_response(:backend, "HTTP/1.1 200 OK#{CRLF}#{CRLF}")
      @handler.response_body_size.should == 0
    end

    it "increments once the body beings" do
      @handler.on_response(:backend, "HTTP/1.1 200 OK#{CRLF}")
      @handler.on_response(:backend, "Transfer-Encoding: chunked#{CRLF}#{CRLF}")
      @handler.on_response(:backend, "5#{CRLF}Body #{CRLF}7#{CRLF}Message#{CRLF}0#{CRLF}#{CRLF}")
      @handler.response_body_size.should == 12
    end

    it "increments if the data is spread across " do
      @handler.on_response(:backend, "HTTP/1.1 200 OK#{CRLF}")
      @handler.on_response(:backend, "Transfer-Encoding: chunked#{CRLF}#{CRLF}")
      @handler.on_response(:backend, "5#{CRLF}Body #{CRLF}7#{CRLF}Message#{CRLF}")
      @handler.on_response(:backend, "8#{CRLF}Another #{CRLF}7#{CRLF}Message#{CRLF}0#{CRLF}#{CRLF}")
      @handler.response_body_size.should == 27
    end

    it "increments by bytesize" do
      @handler.on_response(:backend, "HTTP/1.1 200 OK#{CRLF}")
      @handler.on_response(:backend, "Transfer-Encoding: chunked#{CRLF}#{CRLF}")
      @handler.on_response(:backend, "6#{CRLF}Bödy #{CRLF}7#{CRLF}Message#{CRLF}0#{CRLF}#{CRLF}")
      @handler.response_body_size.should == 13
    end
  end

  describe "request_buffer" do
    before(:each) do
      @handler.stub(:request_headers_parsed) {}
    end

    it "defaults to an empty string" do
      @handler.request_buffer.should == ""
    end

    it "builds the buffer as headers are passed in" do
      chunk1 = "GET / HTTP/1.1#{CRLF}"
      @handler.on_data(chunk1)
      @handler.request_buffer.should == chunk1

      chunk2 = "User-Agent: curl/7.26.0#{CRLF}"
      @handler.on_data(chunk2)
      @handler.request_buffer.should == "#{chunk1}#{chunk2}"
    end

    it "contains body content included in the closing header chunk" do
      chunk1 = "GET / HTTP/1.1#{CRLF}"
      @handler.on_data(chunk1)
      @handler.request_buffer.should == chunk1

      chunk2 = "User-Agent: curl/7.26.0#{CRLF}#{CRLF}Body Message"
      @handler.on_data(chunk2)
      @handler.request_buffer.should == "#{chunk1}#{chunk2}"
    end
  end

  describe "request_headers_parsed" do
    it "does not get called until all headers have been passed in" do
      rack_env = {"HTTP_HOST"=>"localhost", "HTTP_ACCEPT"=>"*/*", "SERVER_NAME"=>"localhost", "REQUEST_METHOD"=>"GET", "REQUEST_URI"=>"/", "QUERY_STRING"=>"", "HTTP_VERSION"=>"1.1", "SCRIPT_NAME"=>"/", "REQUEST_PATH"=>"/", "PATH_INFO"=>"/", "FRAGMENT"=>""}
      @handler.should_not_receive(:request_headers_parsed).with(rack_env)
      @handler.on_data("GET / HTTP/1.1#{CRLF}")
      @handler.on_data("Host: localhost#{CRLF}")
      @handler.on_data("Accept: */*#{CRLF}")
    end

    it "gets called with the rack env after all headers have been passed in" do
      rack_env = {"HTTP_HOST"=>"localhost", "HTTP_ACCEPT"=>"*/*", "SERVER_NAME"=>"localhost", "REQUEST_METHOD"=>"GET", "REQUEST_URI"=>"/", "QUERY_STRING"=>"", "HTTP_VERSION"=>"1.1", "SCRIPT_NAME"=>"/", "REQUEST_PATH"=>"/", "PATH_INFO"=>"/", "FRAGMENT"=>""}
      @handler.should_receive(:request_headers_parsed).with(rack_env)
      @handler.on_data("GET / HTTP/1.1#{CRLF}")
      @handler.on_data("Host: localhost#{CRLF}")
      @handler.on_data("Accept: */*#{CRLF}")
      @handler.on_data(CRLF)
    end

    describe "successful proxy instruction" do
      before(:each) do
        @headers = { "Content-Type" => "text/plain" }
        @handler.stub(:gatekeeper_instruction) do
          {
            :status => 200,
            :headers => @headers,
            :response => ["OK"],
          }
        end
      end

      it "establishes a connection with the backend" do
        @connection.should_receive(:server).with(:api_router, :host => "127.0.0.1", :port => 50100)
        @handler.request_headers_parsed({})
      end

      it "relays the request buffer to the backend" do
        request = "GET / HTTP/1.1#{CRLF}Host: localhost#{CRLF}#{CRLF}Body Message"
        @handler.on_data(request)

        @relayed_request.should == request
      end

      it "does not directly respond to the client" do
        @handler.request_headers_parsed({})
        @sent_response.should == ""
      end
    end

    describe "error proxy instruction" do
      before(:each) do
        @headers = { "Content-Type" => "text/plain" }
        @handler.stub(:gatekeeper_instruction) do
          {
            :status => 403,
            :headers => @headers,
            :response => ["Body ", "message"],
          }
        end
      end

      it "sends the error response" do
        Timecop.freeze do
          expected_response = "HTTP/1.1 403 Forbidden\r\nContent-Type: text/plain\r\nConnection: close\r\nDate: #{Time.now.httpdate}\r\n\r\nBody message"

          @handler.request_headers_parsed({})
          @sent_response.should == expected_response
        end
      end

      it "closes the connection after writing" do
        @connection.should_receive(:close_connection_after_writing)
        @handler.request_headers_parsed({})
      end

      it "closes the error response http object" do
        ApiUmbrella::Gatekeeper::HttpResponse.any_instance.should_receive(:close)
        @handler.request_headers_parsed({})
      end

      it "closes the connection after writing" do
        @connection.should_receive(:close_connection_after_writing)
        @handler.request_headers_parsed({})
      end

      it "does not relay the request to the backend" do
        @handler.request_headers_parsed({})
        @relayed_request.should == ""
      end
    end
  end
end
