require "http/parser"

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
        #p [:on_response, backend, chunk]

        @response_size += chunk.bytesize
        @response_parser << chunk

        @end_time = Time.now

        chunk
      end

      def on_finish(backend)
        @finish_time = Time.now

        @response_header_size = @response_size - @response_body_size
        @request_header_size = @request_size - @request_body_size
        p [:on_finish, backend]
        #p [:on_finish, :time, (@finish_time.to_f - @connect_time.to_f)]
        p [:on_finish, :time, (@end_time.to_f - @start_time.to_f)]
        p [:on_finish, :relay_time, (@end_time.to_f - @relay_time.to_f)]
        p [:on_finish, :status_code, @response_parser.status_code]
        p [:on_finish, :request_size, @request_size]
        p [:on_finish, :request_header_size, @request_header_size]
        p [:on_finish, :request_body_size, @request_body_size]
        p [:on_finish, :response_size, @response_size]
        p [:on_finish, :response_header_size, @response_header_size]
        p [:on_finish, :response_body_size, @response_body_size]

        :close
      end

      def request_headers_parsed(rack_env)
        #p [:request_headers_parsed]
        #puts rack_env.inspect

        instruction = gatekeeper_instruction(rack_env)
        if(instruction[:status] == 200)
          @connection.server :api_router, self.class.random_api_router_server

          @relay_time = Time.now
          @connection.relay_to_servers @request_buffer
        else
          error_response = ApiUmbrella::Gatekeeper::HttpResponse.new
          error_response.status = instruction[:status]
          error_response.headers = instruction[:headers]
          error_response.body = instruction[:response]

          error_response.each do |chunk|
            # p chunk
            @connection.send_data chunk
          end
          @connection.close_connection_after_writing
          error_response.close
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

      def gatekeeper_instruction(rack_env)
        rack_response = ApiUmbrella::Gatekeeper::RackApp.instance.call(rack_env)

        {
          :status => rack_response[0],
          :headers => rack_response[1],
          :response => rack_response[2],
        }
      end
    end
  end
end
