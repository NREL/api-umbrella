require "rack/auth_proxy/throttle/time_window"

module Rack
  module AuthProxy
    module Throttle
      class Hourly < TimeWindow
        def default_max_per_hour
          @default_max_per_hour ||= options[:max_per_hour] || options[:max] || 3_600
        end

        def max_per_hour(request)
          request.env["rack.api_user"].throttle_hourly_limit || self.default_max_per_hour
        end
        alias_method :max_per_window, :max_per_hour

        protected

        def cache_key(request)
          [super, Time.now.strftime('%Y-%m-%dT%H')].join(':')
        end
      end
    end
  end
end
