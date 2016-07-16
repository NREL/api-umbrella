require "bundler/setup"
Bundler.require(:default)

require "minitest/autorun"
require "active_support/core_ext/hash/deep_merge"

API_UMBRELLA_SRC_ROOT = File.expand_path("../../../", __FILE__)
if(!File.exist?(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella")))
  raise "The calculated root directory does not appear correct: #{API_UMBRELLA_SRC_ROOT}"
end

Dir["support/**/*.rb"].each { |f| require f }

# Start the API Umbrella process to test against.
ApiUmbrellaTests::Process.start

#Typhoeus::Config.verbose = true
