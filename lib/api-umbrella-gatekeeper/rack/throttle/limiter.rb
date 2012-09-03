require "rack/throttle"

module ApiUmbrella
  module Gatekeeper
    module Rack
      module Throttle
        class Limiter < ::Rack::Throttle::Limiter
          def initialize(app, options = {})
            super
          end

          def client_identifier(request)
            if(request.env["rack.api_user"].throttle_by_ip)
              ["ip", request.ip.to_s].join(":")
            else
              ["api_key", request.env["rack.api_user"].api_key].join(":")
            end
          end

          def cache_incr(key, default = 1)
            count = default

            case
            when self.cache.respond_to?(:incr)
              count = self.cache.incr(key)
            else
              count = self.cache_get(key).to_i + 1
              self.cache_set(key, count)
            end

            count
          end
        end
      end
    end
  end
end
