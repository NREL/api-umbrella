module CommonValidations
  BASE_HOST_FORMAT = %r{[a-zA-Z0-9:][a-zA-Z0-9\-\.:]*}
  HOST_FORMAT = %r{\A#{BASE_HOST_FORMAT.source}\z}
  HOST_FORMAT_WITH_WILDCARD = %r{\A(\*|(\*\.|\.)#{BASE_HOST_FORMAT.source}|#{BASE_HOST_FORMAT.source})\z}
  URL_PREFIX_FORMAT = %r{\A/}

  def self.to_js(regex)
    regex.source.gsub(/\A\\A/, "^").gsub(/\\z\z/, "$")
  end
end
