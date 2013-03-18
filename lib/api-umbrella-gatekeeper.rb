require "active_support/core_ext"
require "em-proxy"
require "erb"
require "http/parser"
require "rack"
require "rack/throttle"
require "redis"
require "settingslogic"
require "thin"
require "yaml"

require "api-umbrella/api_request_log"
require "api-umbrella/api_user"

module ApiUmbrella
  module Gatekeeper
    DEFAULT_CONFIG = {
      "throttle" => {
        "http_code" => 429,
        "hourly_max" => 1000,
        "daily_max" => 10000,
      },
    }

    autoload :Config, "api-umbrella-gatekeeper/config"
    autoload :ConnectionHandler, "api-umbrella-gatekeeper/connection_handler"
    autoload :HttpParserHandler, "api-umbrella-gatekeeper/http_parser_handler"
    autoload :HttpResponse, "api-umbrella-gatekeeper/http_response"
    autoload :RackApp, "api-umbrella-gatekeeper/rack_app"
    autoload :RequestParserHandler, "api-umbrella-gatekeeper/request_parser_handler"
    autoload :ResponseParserHandler, "api-umbrella-gatekeeper/response_parser_handler"
    autoload :Server, "api-umbrella-gatekeeper/server"

    module Rack
      autoload :Authenticate, "api-umbrella-gatekeeper/rack/authenticate"
      autoload :Authorize, "api-umbrella-gatekeeper/rack/authorize"
      autoload :FormattedErrorResponse, "api-umbrella-gatekeeper/rack/formatted_error_response"

      module Throttle
        autoload :Daily, "api-umbrella-gatekeeper/rack/throttle/daily"
        autoload :Hourly, "api-umbrella-gatekeeper/rack/throttle/hourly"
        autoload :Limiter, "api-umbrella-gatekeeper/rack/throttle/limiter"
        autoload :TimeWindow, "api-umbrella-gatekeeper/rack/throttle/time_window"
      end
    end

    mattr_accessor :redis

    mattr_accessor :logger
    $stdout.sync = true
    self.logger = Logger.new($stdout)

    mattr_accessor :config
    def self.config
      @@config ||= ApiUmbrella::Gatekeeper::Config.new(DEFAULT_CONFIG)
    end
  end
end
