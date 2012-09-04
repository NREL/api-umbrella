module ApiUmbrella
  module Gatekeeper
    class HttpParserHandler
      attr_reader :parser
      attr_reader :connection_handler

      def initialize(connection_handler)
        @connection_handler = connection_handler
        @parser = Http::Parser.new(self)
      end
    end
  end
end
