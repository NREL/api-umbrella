require "em-proxy"

require "api-umbrella-gatekeeper/connection_handler"

module ApiUmbrella
  module Gatekeeper
    class Server
      def self.run(options = {})
        Proxy.start(options) do |conn|
          @handler = ConnectionHandler.new(conn)
          conn.on_data { |data| @handler.on_data(data) }
          conn.on_response { |backend, resp| @handler.on_response(backend, resp) }
          conn.on_finish { |backend| @handler.on_finish(backend) }
          conn.on_connect { |data| p [:on_connect, data] }
        end
      end
    end
  end
end
