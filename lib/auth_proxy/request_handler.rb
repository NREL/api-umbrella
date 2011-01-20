require "thin_parser"
require "auth_proxy/http_response"
require "auth_proxy/rack_app"

# Raised by Thin's Thin::HttpParser when an incoming request is not valid and
# the server can not process it.
class InvalidRequest < IOError; end

module AuthProxy
  # After our ProxyMachine server has received the full HTTP request headers,
  # parsing those headers and determing a response is handled by this class.
  #
  # This can be used inside a ProxyMachine server's configuration to parse the
  # headers and then return a ProxyMachine response:
  #
  #     handler = AuthProxy::RequestHandler.new(headers)
  #     handler.proxy_instruction
  class RequestHandler
    # @return [String] The raw HTTP headers in string format.
    attr_reader :headers

    API_ROUTER_SERVERS = [
      { :host => "127.0.0.1", :port => 50100 }
    ]

    # Create a new class for determing our ProxyMachine server's response,
    # based on the HTTP headers available.
    #
    # @param [String] headers The full, raw HTTP headers for an incoming
    # request.
    def initialize(headers)
      @headers = headers
    end

    # Parse the HTTP headers from their raw string format into a hash of key
    # and value pairs.
    #
    # @return [Hash] The HTTP headers for the request in a hash format.
    def request_env
      unless @request_env
        @request_env = {}

        # Parse the headers using Thin's http_parser. http_parser will place the
        # parsed headers into the env hash we pass in.
        http_parser = Thin::HttpParser.new
        @request_env = {
          "rack.input" => StringIO.new, # So Rack::Request can pretend like it has a body.
        }
        start = 0
        http_parser.execute(@request_env, self.headers, start)

        LOGGER.debug("Request: #{@request_env.inspect}")
      end

      @request_env
    end

    # Return the proper response instruction for the ProxyMachine server. This
    # is determined by using the parsed headers and feeding it to our Rack
    # application. The Rack application makes it easy to use Rack middleware to
    # process the request and handle the real logic.
    #
    # @return [Hash] A ProxyMachine response instruction.
    def proxy_instruction
      status, headers, body = AuthProxy::RackApp.instance.call(self.request_env)

      if(status == 200)
        { :remote => self.class.random_api_router_server }
      else
        response = AuthProxy::HttpResponse.new(status, headers, body)
        { :close => response.to_s }
      end
    end

    # Pick a random API Router server out of a possible cluster of router
    # servers. This is the server that ProxyMachine passes the request onto
    # assuming the request has been authenticated.
    #
    # @see API_ROUTER_SERVERS
    # @return [String] The host and port of a routing server to connect to.
    def self.random_api_router_server
      server_config = API_ROUTER_SERVERS[Kernel.rand(API_ROUTER_SERVERS.length)]
      "#{server_config[:host]}:#{server_config[:port]}"
    end
  end
end
