require "rack"
require "rack/auth_proxy/authenticate"
require "rack/auth_proxy/authorize"
require "rack/auth_proxy/formatted_error_response"
require "rack/auth_proxy/log"
require "rack/auth_proxy/throttle"
require "redis"

module AuthProxy
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
        use Rack::AuthProxy::Log
        use Rack::AuthProxy::FormattedErrorResponse
        use Rack::AuthProxy::Authenticate
        use Rack::AuthProxy::Authorize
        use Rack::AuthProxy::Throttle::Daily,
          :cache => AuthProxy::RackApp.redis_cache,
          :max => 10000,
          :code => 503
        use Rack::AuthProxy::Throttle::Hourly,
          :cache => AuthProxy::RackApp.redis_cache,
          :max => 1000,
          :code => 503

        # Return a 200 OK status if all the middlewares pass through
        # successfully. This indicates to the calling AuthProxy::RequestHandler
        # that no errors have occurred processing the headers, and the
        # application can continue with a instruction to proxymachine.
        run lambda { |env| [200, {}, ["OK"]] }
      end
    end
  end
end
