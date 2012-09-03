module ApiUmbrella
  module Gatekeeper
    class HttpParserHandler
      attr_reader :connection_handler

      def initialize(connection_handler)
        @connection_handler = connection_handler
      end
    end
  end
end
