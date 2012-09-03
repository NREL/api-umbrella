require "rack"
require "api-umbrella-gatekeeper/rack/authenticate"
require "api-umbrella-gatekeeper/rack/authorize"
require "api-umbrella-gatekeeper/rack/formatted_error_response"
require "api-umbrella-gatekeeper/rack/log"
require "api-umbrella-gatekeeper/rack/throttle"
require "redis"

module ApiUmbrella
  module Gatekeeper
    class RackApp
      def self.redis_cache
        @@redis_cache ||= Redis.new(self.redis_config)
      end

      @@redis_config = nil
      def self.redis_config
        unless @@redis_config
          config_path = ::File.join(AUTH_PROXY_ROOT, "config", "redis.yml")
          @@redis_config = YAML.load(ERB.new(File.read(config_path)).result)[ENV["RACK_ENV"]] 
          @@redis_config ||= {}
          @@redis_config.symbolize_keys!
        end

        @@redis_config
      end

      def self.instance
        @@instance ||= Rack::Builder.app do
          use ApiUmbrella::Gatekeeper::Rack::Log
          use ApiUmbrella::Gatekeeper::Rack::FormattedErrorResponse
          use ApiUmbrella::Gatekeeper::Rack::Authenticate
          use ApiUmbrella::Gatekeeper::Rack::Authorize
          use ApiUmbrella::Gatekeeper::Rack::Throttle::Daily,
            :cache => ApiUmbrella::Gatekeeper::RackApp.redis_cache,
            :max => 10000,
            :code => 503
          use ApiUmbrella::Gatekeeper::Rack::Throttle::Hourly,
            :cache => ApiUmbrella::Gatekeeper::RackApp.redis_cache,
            :max => 1000,
            :code => 503

          # Return a 200 OK status if all the middlewares pass through
          # successfully. This indicates to the calling ApiUmbrella::Gatekeeper::RequestHandler
          # that no errors have occurred processing the headers, and the
          # application can continue with a instruction to proxymachine.
          run lambda { |env| [200, {}, ["OK"]] }
        end
      end
    end
  end
end
