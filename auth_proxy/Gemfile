source :rubygems

# Run everything through the ProxyMachine server.
gem "proxymachine"

# For some of activesupport's niceties, like blank?
gem "activesupport", "~> 3.0.10"

# MongoDB
gem "mongoid"

# Lock the BSON version dependency, since the 1.3 branch didn't do this.
gem "bson", "~> 1.3.1"
gem "bson_ext", "~> 1.3.1"

# Rack for contructing our proxy using modularized middlewares.
gem "rack"

# rack-throttle and redis for rate limiting. Use hiredis for better
# performance.
gem "rack-throttle"
gem "hiredis"
gem "redis", :require => ["redis", "redis/connection/hiredis"]

platforms :ruby_18 do
  # Redis recommends SystemTimer over the default Timeout class.
  gem "SystemTimer", "1.2.3"
end

# Use thin for parsing the raw HTTP requests.
gem "thin"

# Yajl for JSON encoding.
gem "yajl-ruby"

group :development do
  # Yard and markdown dependencies
  gem "yard"
  gem "kramdown"
end

# Gems for testing
group :test, :development do
  gem "rspec"

  # For building objects.
  gem "factory_girl"

  # For clearing the database between tests.
  gem "database_cleaner"

  # For simulating calls to our Rack middleware.
  gem "rack-test"

  # For validating Time.now usage inside Rack::AuthProxy::Log
  gem "timecop"

  # For validating XML.
  gem "nokogiri"
end
