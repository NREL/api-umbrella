module ApiUmbrella
  module Gatekeeper
    # The Gatekeeper needs to respond with possible authentication and rate
    # limiting errors. Since our proxy exists at a low level, we need to respond
    # with a raw HTTP response. To make this easier, we'll take advantage of
    # Thin's Thin::Response class to handle most of this.
    class HttpResponse < Thin::Response
      DATE = "Date".freeze

      # String representation of the headers to be sent in the response.
      # Overriden to remove "Thin" as the identifying server.
      #
      # @return [String] The HTTP headers to send in the response.
      def headers_output
        @headers[CONNECTION] = persistent? ? KEEP_ALIVE : CLOSE
        @headers[DATE] = Time.now.httpdate
        @headers.to_s
      end
    end
  end
end
