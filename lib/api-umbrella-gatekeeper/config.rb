module ApiUmbrella
  module Gatekeeper
    class Config < Settingslogic
      namespace ENV["RACK_ENV"]
    end
  end
end
