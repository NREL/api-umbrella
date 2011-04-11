source :rubygems

# Run everything through the ProxyMachine server.
gem "proxymachine", "1.2.4"

# For some of activesupport's niceties, like blank?
gem "activesupport", "3.0.6"

# MongoDB
gem "mongoid", "2.0.1"
gem "bson_ext", "1.3.0"
gem "mongo_ext", "0.19.3"

# Rack for contructing our proxy using modularized middlewares.
gem "rack", "1.2.2"

# rack-throttle and redis for rate limiting.
gem "rack-throttle", "0.3.0"
gem "redis", "2.2.0"

platforms :ruby_18 do
  # Redis recommends SystemTimer over the default Timeout class.
  gem "SystemTimer", "1.2.3"
end

# Use thin for parsing the raw HTTP requests.
gem "thin", "1.2.11"

# Yajl for JSON encoding.
gem "yajl-ruby", "0.8.2"

group :development do
  # Yard and markdown dependencies
  gem "yard", "0.6.7"
  gem "kramdown", "0.13.2"
end

# Gems for testing
group :test, :development do
  gem "rspec", "2.5.0"

  # For building objects.
  gem "factory_girl", "1.3.3"

  # For clearing the database between tests.
  gem "database_cleaner", "0.6.6"

  # For simulating calls to our Rack middleware.
  gem "rack-test", "0.5.7"

  # For validating Time.now usage inside Rack::AuthProxy::Log
  gem "timecop", "0.3.5"

  # For validating XML.
  gem "nokogiri", "1.4.4"
end
