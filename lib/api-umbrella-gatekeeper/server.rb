module ApiUmbrella
  module Gatekeeper
    class Server
      def self.run(options = {})
        ENV["RACK_ENV"] ||= options[:environment] || "development"

        options[:backends] = options[:backend] if(options[:backend])

        if options[:config]
          config = ApiUmbrella::Gatekeeper::Config.new(options[:config])
          ApiUmbrella::Gatekeeper.config = ApiUmbrella::Gatekeeper::DEFAULT_CONFIG.deep_merge(config.to_hash)
        end

        ApiUmbrella::Gatekeeper.config["host"] = options[:host] if(options[:host])
        ApiUmbrella::Gatekeeper.config["port"] = options[:port] if(options[:port])
        ApiUmbrella::Gatekeeper.config["backends"] = options[:backends] if(options[:backends])

        if options[:mongoid_config]
          Mongoid.load!(options[:mongoid_config])
        end

        if options[:redis_config]
          redis_config = YAML.load(ERB.new(File.read(options[:redis_config])).result)[ENV["RACK_ENV"]]
          ApiUmbrella::Gatekeeper.redis = Redis.new(redis_config)
        end

        Proxy.start(:host => ApiUmbrella::Gatekeeper.config["host"], :port => ApiUmbrella::Gatekeeper.config["port"]) do |conn|
          @handler = ConnectionHandler.new(conn)
          conn.on_data { |data| @handler.on_data(data) }
          conn.on_response { |backend, resp| @handler.on_response(backend, resp) }
          conn.on_finish { |backend| @handler.on_finish(backend) }
        end
      end
    end
  end
end
