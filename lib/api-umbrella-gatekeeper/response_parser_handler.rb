module ApiUmbrella
  module Gatekeeper
    class ResponseParserHandler < HttpParserHandler
      def on_body(chunk)
        #p [:response, :on_body, chunk]
        connection_handler.response_body_size += chunk.bytesize
      end
    end
  end
end
