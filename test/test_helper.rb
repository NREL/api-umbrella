require "bundler/setup"
Bundler.require(:default)

require "minitest/autorun"

# Add the test root directory to the default load path, regardless of where
# tests are run from.
$LOAD_PATH.unshift(File.dirname(__FILE__))

API_UMBRELLA_SRC_ROOT = File.expand_path("../../", __FILE__)
if(!File.exist?(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella")))
  raise "The calculated root directory does not appear correct: #{API_UMBRELLA_SRC_ROOT}"
end

Dir[File.expand_path("../support/models/*.rb", __FILE__)].each { |f| require f }
Dir[File.expand_path("../support/models/**/*.rb", __FILE__)].each { |f| require f }
Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |f| require f }
