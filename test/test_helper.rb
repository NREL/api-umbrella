require "bundler/setup"
Bundler.require(:default)

require "minitest/autorun"

# Add the test root directory to the default load path, regardless of where
# tests are run from.
$LOAD_PATH.unshift(File.dirname(__FILE__))

# Detect the source root directory.
API_UMBRELLA_SRC_ROOT = File.expand_path("../../", __FILE__)
if(!File.exist?(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella")))
  raise "The calculated root directory does not appear correct: #{API_UMBRELLA_SRC_ROOT}"
end

# Add our build directories to the $PATH. This ensures that when we spin up the
# API Umbrella process, we use the latest version of whatever's built locally
# (rather than using whatever versions of things might be installed at the
# system level).
ENV["PATH"] = [
  "#{API_UMBRELLA_SRC_ROOT}/build/work/stage/opt/api-umbrella/embedded/bin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/stage/opt/api-umbrella/embedded/sbin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/test-env/bin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/test-env/sbin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/dev-env/bin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/dev-env/sbin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/cmake/bin",
  ENV["PATH"],
].join(":")

# Load all the support files. Load models first, so they're defined for other
# helpers.
Dir[File.expand_path("../support/models/*.rb", __FILE__)].each { |f| require f }
Dir[File.expand_path("../support/models/**/*.rb", __FILE__)].each { |f| require f }
Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |f| require f }
