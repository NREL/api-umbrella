require "http/parser"
require "rack/request"

require "api-umbrella/api_request_log"

require "api-umbrella-gatekeeper/http_response"
require "api-umbrella-gatekeeper/rack_app"
require "api-umbrella-gatekeeper/request_parser_handler"
require "api-umbrella-gatekeeper/response_parser_handler"

module ApiUmbrella
  module Gatekeeper
    class ConnectionHandler
      API_ROUTER_SERVERS = [
        { :host => "127.0.0.1", :port => 50100 }
      ]

      attr_reader :connection, :start_time, :end_time, :request_buffer, :request_size, :response_size
      attr_accessor :request_body_size, :response_body_size

      def initialize(connection)
        @connection = connection

        @start_time = nil
        @end_time = nil

        @request_buffer = ""
        @request_headers_parsed = false

        @request_size = 0
        @request_body_size = 0

        @response_size = 0
        @response_body_size = 0

        @request_parser_handler = RequestParserHandler.new(self)
        @request_parser = @request_parser_handler.parser

        @response_parser_handler = ResponseParserHandler.new(self)
        @response_parser = @response_parser_handler.parser
      end

      def on_data(chunk)
        unless @start_time
          @start_time = Time.now
        end

        #p [:on_data, chunk]

        @request_size += chunk.bytesize

        unless @request_headers_parsed
          @request_buffer << chunk
        end

        @request_parser << chunk

        if @request_buffer.empty?
          chunk
        else
          nil
        end
      end

      def on_response(backend, chunk)
        handle_response_chunk(chunk)

        @end_time = Time.now

        chunk
      end

      def on_finish(backend)
        @finish_time = Time.now

        @backend_time = @end_time.to_f - @backend_start_time.to_f

        log

        :close
      end

      def request_headers_parsed(rack_env)
        @rack_env = rack_env

        instruction = gatekeeper_instruction(@rack_env)
        if(instruction[:status] == 200)
          @connection.server :api_router, self.class.random_api_router_server

          @backend_start_time = Time.now
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
      def self.random_api_router_server
        API_ROUTER_SERVERS[Kernel.rand(API_ROUTER_SERVERS.length)]
      end

      private

      def handle_response_chunk(chunk)
        @response_size += chunk.bytesize
        @response_parser << chunk
      end

      def gatekeeper_instruction(rack_env)
        rack_response = ApiUmbrella::Gatekeeper::RackApp.instance.call(rack_env)

        {
          :status => rack_response[0],
          :headers => rack_response[1],
          :response => rack_response[2],
        }
      end

      def log
        request = ::Rack::Request.new(@rack_env)

        log_data = {
          :api_key => @rack_env["rack.api_key"],
          :path => request.path,
          :ip_address => request.ip,

          :requested_at => @start_time,
          :time => @end_time.to_f - @start_time.to_f,
          :backend_time => @backend_time,

          :request_size => @request_size,
          :request_header_size => @request_size - @request_body_size,
          :request_body_size => @request_body_size,
          :request_headers => @request_parser.headers,

          :response_status => @response_parser.status_code,
          :response_size => @response_size,
          :response_header_size => @response_size - @response_body_size,
          :response_body_size => @response_body_size,
          :response_headers => @response_parser.headers,
        }

        @finish_time = Time.now
        log_data[:finish_time] = @finish_time.to_f - @start_time.to_f
        log_data[:proxy_time] = log_data[:finish_time] - log_data[:backend_time].to_f

        # Create a new log entry for this request, saving asynchronously.
        log = ApiUmbrella::ApiRequestLog.new(log_data)
        log.save(:validate => false, :safe => false)
      end
    end
  end
end
