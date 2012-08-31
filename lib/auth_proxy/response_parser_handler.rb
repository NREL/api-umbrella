require "auth_proxy/http_parser_handler"

module AuthProxy
  class ResponseParserHandler < HttpParserHandler
    def on_body(chunk)
      #p [:response, :on_body, chunk]
      connection_handler.response_body_size += chunk.bytesize
    end
  end
end
