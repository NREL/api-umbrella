module ApiUmbrellaTestHelpers
  module KeepAliveTestServer
    private

    @@server_thread = nil
    @@server = nil

    # An API backend server for inspecting the behavior of keep alive
    # connections on API backends.
    #
    # This server keeps counters of the number of open connections and open
    # requests. The requests and connection counts  may differ since keep-alive
    # connections can reuse connections for multiple requests, and some
    # connections are expected to remain open for reuse after the requests
    # finish.
    #
    # We're using EventMachine for this test server, instead of the OpenResty
    # test server we use for all the other tests, since we need lower-level
    # access to distinguish between TCP connections opening and closing and
    # HTTP requests beginning and finishing.
    class KeepAliveServer < EventMachine::Connection
      @@open_connections = Concurrent::AtomicFixnum.new(0)
      @@open_requests = Concurrent::AtomicFixnum.new(0)

      def post_init
        @@open_connections.increment
      end

      def unbind
        @@open_connections.decrement
      end

      def receive_data(data)
        # We're acting as a dumb HTTP server, so just consider a request
        # finished once the data chunk contains the final piece of the HTTP
        # headers.
        if(data.include?("\r\n\r\n"))
          @@open_requests.increment

          # Delay the response a bit, since this seems to help ensure nginx
          # establishes the expected number of keepalive connections (if the
          # requests are too quick, nginx may not open up enough connections).
          EventMachine.add_timer(0.5) do
            body = MultiJson.dump({
              :open_requests => @@open_requests.value,
              :open_connections => @@open_connections.value,
            })

            send_data "HTTP/1.1 200 OK\r\n" +
              "Connection: keep-alive\r\n" +
              "Content-Type: application/json\r\n" +
              "Content-Length: #{body.bytesize}\r\n" +
              "\r\n" +
              body

            @@open_requests.decrement
          end
        end
      end
    end

    def start_keep_alive_test_server
      @@server_thread = Thread.new do
        EventMachine.run {
          @@server = EventMachine.start_server("127.0.0.1", 9445, KeepAliveServer)
        }
      end
    end

    def stop_keep_alive_test_server
      if(EventMachine.reactor_running?)
        if(@@server)
          EventMachine.stop_server(@@server)
        end
        EventMachine.stop
      end

      if(@@server_thread && @@server_thread.alive?)
        @@server_thread.exit
      end
    end
  end
end
