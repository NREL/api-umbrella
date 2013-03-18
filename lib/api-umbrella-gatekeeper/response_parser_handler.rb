module ApiUmbrella
  module Gatekeeper
    class ResponseParserHandler < HttpParserHandler
      def on_message_complete
        connection_handler.response_completed = true
      end
    end
  end
end
