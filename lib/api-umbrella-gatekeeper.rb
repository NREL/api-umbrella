require "active_support/core_ext"

module ApiUmbrella
  module Gatekeeper
    mattr_accessor :redis

    mattr_accessor :logger

    $stdout.sync = true
    self.logger = Logger.new($stdout)
  end
end

require "api-umbrella-gatekeeper/server"
