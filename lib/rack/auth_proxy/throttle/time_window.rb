require "rack/auth_proxy/throttle/limiter"

module Rack
  module AuthProxy
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
              LOGGER.error(e.to_s)
              LOGGER.error(e.backtrace.join("\n"))
            end
          end

          allowed
        end
      end
    end
  end
end
