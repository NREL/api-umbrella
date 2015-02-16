require "mustache"

module ApiUmbrella
  class ConfigTemplate < Mustache
    def escapeHTML(str)
      str
    end
  end
end
