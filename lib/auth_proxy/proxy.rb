require "auth_proxy/request_handler"

module AuthProxy
  class Proxy
    LF = "\n"
    CRLF = "\r\n"

    def self.proxymachine_router
      lambda { |data|
        begin
          # Keep reading data until we have all of the headers. The headers end when
          # there's a header line followed by a blank line. Technically HTTP requires
          # these line breaks to be CRLF, but apparently it's good to support just LF
          # too.
          if(data =~ /^(.+(#{CRLF}|#{LF})(#{CRLF}|#{LF}))/m)
            headers = $1

            handler = AuthProxy::RequestHandler.new(headers)
            handler.proxy_instruction
          else
            # Keep reading until we have the full headers.
            { :noop => true }
          end
        rescue Exception => e
          LOGGER.error(e.to_s)
          LOGGER.error(e.backtrace.join("\n"))
        end
      }
    end
  end
end
