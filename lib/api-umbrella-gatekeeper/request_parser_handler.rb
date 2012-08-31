require "auth_proxy/http_parser_handler"

module AuthProxy
  class RequestParserHandler < HttpParserHandler
    def on_headers_complete(headers)
      #p [:request, :on_headers_complete, headers]
      connection_handler.request_headers_parsed(headers)
    end

    def on_body(chunk)
      #p [:request, :on_body, chunk]
      connection_handler.request_body_size += chunk.bytesize
    end
  end
end
