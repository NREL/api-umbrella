# encoding: utf-8

require "spec_helper"

describe ApiUmbrella::Gatekeeper::Server do
  describe "logging" do
    CRLF = "\r\n"

    before(:all) do
      @api_user = FactoryGirl.create(:api_user)
    end

    before(:each) do
      ApiUmbrella::ApiRequestLog.delete_all
    end

    it "creates a log entry for a successful request" do
      make_request(:get, "/hello?api_key=#{@api_user.api_key}")

      log = ApiUmbrella::ApiRequestLog.last
      log.should_not eq(nil)
      log.response_status.should eq(200)
    end

    it "creates a log entry for an unauthenticated request" do
      make_request(:get, "/hello")

      log = ApiUmbrella::ApiRequestLog.last
      log.should_not eq(nil)
      log.response_status.should eq(403)
    end

    describe "api key" do
      it "logs the api key for a successful request" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.api_key.should eq(@api_user.api_key)
      end

      it "logs nothing for an unauthenticated request" do
        make_request(:get, "/hello")

        log = ApiUmbrella::ApiRequestLog.last
        log.api_key.should eq(nil)
      end
    end

    describe "full path" do
      it "logs the path and query string" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}&hello=goodbye")

        log = ApiUmbrella::ApiRequestLog.last
        log.fullpath.should eq("/hello?api_key=#{@api_user.api_key}&hello=goodbye")
      end
    end

    describe "ip address" do
      it "logs the ip address" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.ip_address.should eq("127.0.0.1")
      end

      it "logs the forwarded ip address" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}", {
          :head => { "X-Forwarded-For" => "4.4.4.4" },
        })

        log = ApiUmbrella::ApiRequestLog.last
        log.ip_address.should eq("4.4.4.4")
      end

      it "ignores forwarded ips from untrusted proxies" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}", {
          :head => { "X-Forwarded-For" => "4.4.4.4, 3.3.3.3, 127.0.0.1" },
        })

        log = ApiUmbrella::ApiRequestLog.last
        log.ip_address.should eq("3.3.3.3")
      end
    end

    describe "request size metrics" do
      it "measures request header size" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")
        log1 = ApiUmbrella::ApiRequestLog.last
        log1.request_header_size.should be > 0

        make_request(:get, "/hello2?api_key=#{@api_user.api_key}")
        log2 = ApiUmbrella::ApiRequestLog.last
        log2.request_header_size.should be > 0
        log2.request_header_size.should eq(log1.request_header_size + 1)
      end

      it "measures request body size" do
        make_request(:post, "/hello?api_key=#{@api_user.api_key}", :body => "goodbye")
        log1 = ApiUmbrella::ApiRequestLog.last
        log1.request_body_size.should eq(7)

        make_request(:post, "/hello?api_key=#{@api_user.api_key}", :body => "goodbye2")
        log2 = ApiUmbrella::ApiRequestLog.last
        log2.request_body_size.should eq(8)
      end



      it "measures total request size" do
        make_request(:post, "/hello?api_key=#{@api_user.api_key}", :body => "goodbye")

        log = ApiUmbrella::ApiRequestLog.last
        log.request_total_size.should be > 0
        log.request_total_size.should eq(log.request_header_size + log.request_body_size)
      end

      it "uses bytesize for measuring utf8 characters" do
        make_request(:post, "/hello?api_key=#{@api_user.api_key}", {
          :head => { "X-Example" => "tést" },
          :body => "göödbye",
        })

        log = ApiUmbrella::ApiRequestLog.last
        log.request_header_size.should eq(165)
        log.request_body_size.should eq(9)
        log.request_total_size.should eq(174)
      end

      it "measures the request size when spread across multiple request chunks" do
        send_chunks([
          "GET /hello?api_key=#{@api_user.api_key} HTTP/1.1#{CRLF}",
          "Transfer-Encoding: chunked#{CRLF}",
          "Content-Type: application/x-www-form-urlencoded#{CRLF}#{CRLF}5#{CRLF}Body ",
          "#{CRLF}7#{CRLF}Message#{CRLF}",
          "8#{CRLF}Another #{CRLF}7#{CRLF}Massage#{CRLF}0#{CRLF}#{CRLF}",
        ])

        log = ApiUmbrella::ApiRequestLog.last
        log.request_header_size.should eq(126)
        log.request_body_size.should eq(52)
        log.request_total_size.should eq(178)
      end

      context "unauthenticated requests" do
        it "only measures the body contained in the header chunks (since we stop reading the body for unauthenticated requests)" do
          send_chunks([
            "GET /hello HTTP/1.1#{CRLF}",
            "Transfer-Encoding: chunked#{CRLF}",
            "Content-Type: application/x-www-form-urlencoded#{CRLF}#{CRLF}5#{CRLF}Body ",
            "#{CRLF}7#{CRLF}Message#{CRLF}",
            "8#{CRLF}Another #{CRLF}",
            "8#{CRLF}Another #{CRLF}",
            "7#{CRLF}Massage#{CRLF}",
            "0#{CRLF}#{CRLF}",
          ])

          log = ApiUmbrella::ApiRequestLog.last
          log.request_body_size.should eq(8)
        end

        it "only measures the body inside the first 16K of the request when the body is sent in as a single chunk" do
          body = "1" * 100000
          send_chunks([
            "POST /hello HTTP/1.1#{CRLF}Content-Length: #{body.bytesize}#{CRLF}#{CRLF}#{body}",
          ])

          log = ApiUmbrella::ApiRequestLog.last
          log.request_body_size.should eq(16336)
        end
      end
    end

    describe "response size metrics" do
      it "measures response header size" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.response_header_size.should be > 0
      end

      it "measures response body size" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.response_body_size.should eq(11)
      end

      it "measures total response size" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.response_total_size.should be > 0
        log.response_total_size.should eq(log.response_header_size + log.response_body_size)
      end

      it "uses bytesize for measuring utf8 characters" do
        make_request(:get, "/utf8?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.response_header_size.should eq(263)
        log.response_body_size.should eq(13)
        log.response_total_size.should eq(276)
      end

      it "measures the response size when spread across multiple response chunks" do
        # Make sure the response actually got spread across multiple response
        # chunks. Not all rack servers support this, but Unicron currently
        # does.
        ApiUmbrella::Gatekeeper::ConnectionHandler.any_instance.should_receive(:on_response).at_least(3).times.and_call_original

        send_chunks([
          "GET /chunked?api_key=#{@api_user.api_key} HTTP/1.1#{CRLF}#{CRLF}",
        ])

        log = ApiUmbrella::ApiRequestLog.last
        log.response_header_size.should eq(253)
        log.response_body_size.should eq(27)
        log.response_total_size.should eq(280)
      end
    end

    describe "response status code" do
      it "logs the status code for a successful request" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.response_status.should eq(200)
      end

      it "logs the status code for an unauthenticated request" do
        make_request(:get, "/hello")

        log = ApiUmbrella::ApiRequestLog.last
        log.response_status.should eq(403)
      end

      it "logs the status code for an error from the backend server" do
        make_request(:get, "/404?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.response_status.should eq(404)
      end
    end

    describe "timing" do
      it "logs the timestamp of the request" do
        Timecop.freeze do
          make_request(:get, "/hello")

          log = ApiUmbrella::ApiRequestLog.last
          log.requested_at.utc.to_i.should == Time.now.utc.to_i
        end
      end

      it "logs the timestamp of the when the request started, not finished" do
        start_time = Time.now
        send_chunks([
          "GET /hello?api_key=#{@api_user.api_key} HTTP/1.1#{CRLF}",
          "Transfer-Encoding: chunked#{CRLF}",
          "Content-Type: application/x-www-form-urlencoded#{CRLF}#{CRLF}5#{CRLF}Body ",
          "#{CRLF}7#{CRLF}Message#{CRLF}",
          "8#{CRLF}Another #{CRLF}7#{CRLF}Massage#{CRLF}0#{CRLF}#{CRLF}",
        ], 0.3)
        end_time = Time.now

        log = ApiUmbrella::ApiRequestLog.last
        log.requested_at.utc.to_f.should be_within(0.2).of(start_time.utc.to_f)
        log.requested_at.utc.to_f.should_not be_within(0.2).of(end_time.utc.to_f)
      end

      it "logs timers on how long the request took" do
        make_request(:get, "/sleep?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last

        log.total_time.should be_kind_of(Float)
        log.total_time.should be_within(0.2).of(1.0)

        log.backend_time.should be_kind_of(Float)
        log.backend_time.should be_within(0.2).of(1.0)

        log.proxy_overhead_time.should be_kind_of(Float)
        log.proxy_overhead_time.should be > 0.0
        log.proxy_overhead_time.should be < 0.1
      end

      it "logs timers on request timeouts" do
        make_request(:get, "/sleep_timeout?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last

        log.total_time.should be_kind_of(Float)
        log.total_time.should be_within(0.2).of(1.5)

        log.backend_time.should be_kind_of(Float)
        log.backend_time.should be_within(0.2).of(1.5)

        log.proxy_overhead_time.should be_kind_of(Float)
        log.proxy_overhead_time.should be > 0.0
        log.proxy_overhead_time.should be < 0.1
      end

      it "doesn't log backend time for unauthenticated requests" do
        make_request(:get, "/hello")

        log = ApiUmbrella::ApiRequestLog.last
        log.total_time.should be_kind_of(Float)
        log.proxy_overhead_time.should be_kind_of(Float)
        log.backend_time.should eq(nil)
      end
    end

    describe "abort logging" do
      it "doesn't log the request or response as aborted under normal circumstances" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.attributes.key?("request_aborted").should be_false
        log.attributes.key?("response_aborted").should be_false
      end

      it "logs the request as aborted when authentication fails" do
        make_request(:get, "/hello")

        log = ApiUmbrella::ApiRequestLog.last
        log.attributes.key?("response_aborted").should be_false
        log.attributes.key?("request_aborted").should be_true
        log.request_aborted.should eq(true)
      end

      it "logs the response as aborted on request timeouts" do
        make_request(:get, "/sleep_timeout?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last
        log.attributes.key?("request_aborted").should be_false
        log.attributes.key?("response_aborted").should be_true
        log.response_aborted.should eq(true)
      end
    end

    describe "request headers" do
      it "logs the request headers as a hash" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}", {
          :head => { "X-Forwarded-For" => "4.4.4.4" },
        })

        log = ApiUmbrella::ApiRequestLog.last
        log.request_headers.should eq({
          "Connection" => "close",
          "Host" => "127.0.0.1:9333",
          "User-Agent" => "EventMachine HttpClient",
          "X-Forwarded-For" => "4.4.4.4",
        })
      end
    end

    describe "response headers" do
      it "logs the response headers as a hash" do
        make_request(:get, "/hello?api_key=#{@api_user.api_key}")

        log = ApiUmbrella::ApiRequestLog.last

        log.response_headers["Content-Length"].should eq("11")
        log.response_headers.keys.sort.should eq([
          "Connection",
          "Content-Length",
          "Content-Type",
          "Date",
          "Status",
          "X-Content-Type-Options",
          "X-Frame-Options",
          "X-XSS-Protection",
        ])
      end
    end
  end
end
