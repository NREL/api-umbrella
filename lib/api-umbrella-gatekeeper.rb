require "active_support/core_ext"

module ApiUmbrella
  module Gatekeeper
    mattr_accessor :redis_cache
    mattr_accessor :logger
    self.logger = Logger.new(STDOUT)
  end
end
