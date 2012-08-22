require "http/parser"

require "auth_proxy/http_response"
require "auth_proxy/request_parser_handler"
require "auth_proxy/response_parser_handler"

module AuthProxy
  class ConnectionHandler
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

      @request_parser = Http::Parser.new(RequestParserHandler.new(self))
      @response_parser = Http::Parser.new(ResponseParserHandler.new(self))
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

    def request_headers_parsed(headers)
      #p [:request_headers_parsed]
      #puts headers.inspect

      instruction = proxy_instruction(headers)
      if(instruction[:status] == 200)
        #@connection.server :api_router, :host => "www.example.com", :port => 80
        #@connection.server :api_router, :host => "www.google.com", :port => 80
        #@connection.server :api_router, :host => "192.168.50.20", :port => 80
        @connection.server :api_router, :host => "localhost", :port => 3000
        #@connection.server :api_router, :host => "www.nytimes.com", :port => 80
        #@connection.server :api_router, :host => "twitter.com", :port => 80

        @relay_time = Time.now
        @connection.relay_to_servers @request_buffer
      else
        error_response = AuthProxy::HttpResponse.new
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

    private

    def proxy_instruction(headers)
      #status, headers, response = AuthProxy::RackApp.instance.call(headers)

      status = 200
      headers = {
        "Location" => "http://stackoverflow.com/",
      }
      response = "<head><title>Document Moved</title></head>\n<body><h1>Object Moved</h1>This document may be found <a HREF=\"http://stackoverflow.com/\">here</a></body>"

      {
        :status => status,
        :headers => headers,
        :response => response,
      }
    end
  end
end
