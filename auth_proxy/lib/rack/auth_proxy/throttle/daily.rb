require "rack/auth_proxy/throttle/time_window"

module Rack
  module AuthProxy
    module Throttle
      class Daily < TimeWindow
        def default_max_per_day
          @default_max_per_day ||= options[:max_per_day] || options[:max] || 86_400
        end

        def max_per_day(request)
          request.env["rack.api_user"].throttle_daily_limit || self.default_max_per_day
        end
        alias_method :max_per_window, :max_per_day

        protected

        def cache_key(request)
          [super, Time.new.utc.strftime('%Y-%m-%d')].join(':')
        end
      end
    end
  end
end
