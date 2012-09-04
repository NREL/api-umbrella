require "active_support/core_ext"

module ApiUmbrella
  module Gatekeeper
    mattr_accessor :redis

    mattr_accessor :logger
    self.logger = Logger.new(STDOUT)
  end
end

require "api-umbrella-gatekeeper/server"
