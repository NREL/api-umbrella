require "api-umbrella-gatekeeper/rack/throttle/limiter"

module ApiUmbrella
  module Gatekeeper
    module Rack
      module Throttle
        class TimeWindow < Limiter
          def allowed?(request)
            allowed = true

            if(!request.env["rack.api_user"].unthrottled)
              begin
                count = self.cache_incr(self.cache_key(request))
                max = self.max_per_window(request)

                if(!max.nil?)
                  allowed = (count <= max)
                end
              rescue => e
                ApiUmbrella::Gatekeeper.logger.error(e.to_s)
                ApiUmbrella::Gatekeeper.logger.error(e.backtrace.join("\n"))
              end
            end

            allowed
          end
        end
      end
    end
  end
end
