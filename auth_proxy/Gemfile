source :rubygems

gem "activesupport", "3.0.4"

# MongoDB
gem "mongoid", "2.0.0.rc.6"
gem "bson_ext", "1.2.1"
gem "mongo_ext", "0.19.3"

# Rack for contructing our proxy using modularized middlewares.
gem "rack", "1.2.1"

# rack-throttle and redis for rate limiting.
gem "rack-throttle", "0.3.0"
gem "redis", "2.1.1"

# Redis recommends SystemTimer over the default Timeout class.
gem "SystemTimer", "1.2.2"

# Use thin for parsing the raw HTTP requests.
gem "thin", "1.2.7"

# Yajl for JSON encoding.
gem "yajl-ruby", "0.8.1"

group :development do
  # Yard and markdown dependencies
  gem "yard", "0.6.4"
  gem "kramdown", "0.13.1"
end

group :test, :development do
  gem "database_cleaner", "0.6.3"
  gem "factory_girl", "1.3.3"
  gem "rspec", "2.5.0"
  gem "rack-test", "0.5.7"
  gem "minitest", "2.0.2"
  gem "nokogiri", "1.4.4"
  gem "timecop", "0.3.5"
end
