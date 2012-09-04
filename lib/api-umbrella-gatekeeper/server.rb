require "em-proxy"

require "api-umbrella-gatekeeper/connection_handler"

module ApiUmbrella
  module Gatekeeper
    class Server
      def self.run(options = {})
        ENV["RACK_ENV"] = options[:environment] || "development"

        if options[:mongoid_config]
          Mongoid.load!(options[:mongoid_config])
        end

        if options[:redis_config]
          redis_config = YAML.load(ERB.new(File.read(options[:redis_config])).result)[ENV["RACK_ENV"]]
          ApiUmbrella::Gatekeeper.redis = Redis.new(redis_config)
        end

        proxy_options = options.slice(:host, :port)
        puts proxy_options.inspect
        Proxy.start(proxy_options) do |conn|
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
