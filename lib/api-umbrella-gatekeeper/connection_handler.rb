module ApiUmbrella
  module Gatekeeper
    class ConnectionHandler
      API_ROUTER_SERVERS = [
        { :host => "127.0.0.1", :port => 50100 }
      ]

      attr_reader :connection, :request_start_time, :response_end_time, :request_buffer, :request_size, :response_size
      attr_accessor :request_completed, :response_completed

      def initialize(connection)
        @request_start_time = Time.now
        @response_end_time = nil

        @connection = connection
        @backends = ApiUmbrella::Gatekeeper.config["backends"].map do |backend|
          parts = backend.split(":")
          { :host => parts[0], :port => parts[1] }
        end

        @request_buffer = ""
        @request_headers_parsed = false

        @request_size = 0
        @request_header_size = 0

        @response_size = 0
        @response_header_size = 0

        @request_completed = false
        @response_completed = false

        @request_parser_handler = RequestParserHandler.new(self)
        @request_parser = @request_parser_handler.parser

        @response_parser_handler = ResponseParserHandler.new(self)
        @response_parser = @response_parser_handler.parser
      end

      def on_data(chunk)
        #p [:on_data, chunk]

        # Ignore data if the response has already been sent.
        #
        # This can happen if the user sends a large body as part of an
        # unauthenticated request. While we close the client connection as soon
        # as the headers are read in (see request_headers_parsed), EventMachine
        # might still be sending us the request data that it already read in.
        return if(@response_completed)

        @request_size += chunk.bytesize

        chunk_buffered = false
        unless @request_headers_parsed
          @request_buffer << chunk
          chunk_buffered = true
        end

        @request_parser << chunk

        if chunk_buffered
          nil
        else
          chunk
        end
      end

      def on_response(backend, chunk)
        handle_response_chunk(chunk)

        @response_end_time = Time.now

        chunk
      end

      def on_finish(backend)
        #p [:on_finish, backend]

        # In case the request aborts before the response is sent back, define
        # the response end time.
        @response_end_time ||= Time.now

        @backend_time = @response_end_time.to_f - @backend_start_time.to_f

        log

        :close
      end

      def request_headers_parsed(rack_env)
        @rack_env = rack_env

        @request_header_size = @request_buffer.index("\r\n\r\n") + 4

        instruction = gatekeeper_instruction(@rack_env)
        if(instruction[:status] == 200)
          @connection.server :api_router, self.random_backend_server

          @backend_start_time = Time.now
          #p [:relay, @request_buffer]
          @connection.relay_to_servers @request_buffer
        else
          error_response = ApiUmbrella::Gatekeeper::HttpResponse.new
          error_response.status = instruction[:status]
          error_response.headers = instruction[:headers]
          error_response.body = instruction[:response]

          error_response.each do |chunk|
            handle_response_chunk(chunk)
            @connection.send_data chunk
          end

          @connection.close_connection_after_writing
          error_response.close

          @response_completed = true
          @backend_time = nil

          log
        end

        @request_buffer.clear
        @request_headers_parsed = true
      end

      # Pick a random API Router server out of a possible cluster of router
      # servers. This is the server that ProxyMachine passes the request onto
      # assuming the request has been authenticated.
      #
      # @see API_ROUTER_SERVERS
      # @return [String] The host and port of a routing server to connect to.
      def random_backend_server
        @backends[Kernel.rand(@backends.length)]
      end

      private

      def handle_response_chunk(chunk)
        @response_size += chunk.bytesize

        unless @response_headers_parsed
          if(index = chunk.index("\r\n\r\n"))
            @response_header_size += index + 4
            @response_headers_parsed = true
          else
            @response_header_size += chunk.bytesize
          end
        end

        @response_parser << chunk
      end

      def gatekeeper_instruction(rack_env)
        rack = ApiUmbrella::Gatekeeper::RackApp.instance.call(rack_env)
        response = ::Rack::Response.new(rack[2], rack[0], rack[1]).to_a

        {
          :status => response[0],
          :headers => response[1],
          :response => response[2],
        }
      end

      def log
        request = ::Rack::Request.new(@rack_env)

        log_data = {
          :api_key => @rack_env["rack.api_key"],
          :fullpath => request.fullpath,
          :ip_address => request.ip,

          :requested_at => @request_start_time,
          :backend_time => @backend_time,

          :request_total_size => @request_size,
          :request_header_size => @request_header_size,
          :request_body_size => @request_size - @request_header_size,
          :request_headers => @request_parser.headers,

          :response_status => @response_parser.status_code,
          :response_total_size => @response_size,
          :response_header_size => @response_header_size,
          :response_body_size => @response_size - @response_header_size,
          :response_headers => @response_parser.headers,
        }

        log_data[:request_aborted] = true unless(@request_completed)
        log_data[:response_aborted] = true unless(@response_completed)

        @finish_time = Time.now
        log_data[:total_time] = @finish_time.to_f - @request_start_time.to_f
        log_data[:proxy_overhead_time] = log_data[:total_time] - log_data[:backend_time].to_f

        # Create a new log entry for this request, saving asynchronously.
        log = ApiUmbrella::ApiRequestLog.new(log_data)
        log.save(:validate => false, :safe => false)
      end
    end
  end
end
