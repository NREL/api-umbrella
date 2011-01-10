require "thin"

module AuthProxy
  # The AuthProxy needs to respond with possible authentication and rate
  # limiting errors. Since our proxy exists at a low level, we need to respond
  # with a raw HTTP response. To make this easier, we'll take advantage of
  # Thin's Thin::Response class to handle most of this.
  class HttpResponse < Thin::Response
    # Provide an alternate constructor that takes in the response status,
    # headers, and body all during initialization.
    #
    # @param [Integer] status The HTTP status code for the response.
    # @param [Hash] headers The HTTP headers to return in the response.
    # @param [String] body The body of the HTTP response.
    def initialize(status, headers, body)
      super()

      self.status = status
      self.headers = headers
      self.body = body
    end

    # String representation of the headers to be sent in the response.
    # Overriden to remove "Thin" as the identifying server.
    #
    # @return [String] The HTTP headers to send in the response.
    def headers_output
      @headers[CONNECTION] = persistent? ? KEEP_ALIVE : CLOSE
      @headers.to_s
    end

    # Convert the HTTP response to a single string. Since our error responses
    # come from ProxyMachine, and ProxyMachine doesn't support streaming chunks
    # of the response for custom string responses, the entire response needs to
    # be a single string. Since all error messages should be relatively short,
    # this lack of streaming error responses from ProxyMachine shouldn't be a
    # concern.
    #
    # @return [String] The entire HTTP response as a string.
    def to_s
      unless @to_s
        @to_s = ""
        self.each do |chunk|
          @to_s << chunk.to_s
        end
      end

      @to_s
    end
  end
end
