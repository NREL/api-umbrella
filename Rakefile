require "bundler/setup"

# Detect the source root directory.
API_UMBRELLA_SRC_ROOT = File.expand_path("../", __FILE__)
if(!File.exist?(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella")))
  raise "The calculated root directory does not appear correct: #{API_UMBRELLA_SRC_ROOT}"
end

Dir.glob(File.join(API_UMBRELLA_SRC_ROOT, "scripts/rake/*.rake")).each { |r| import r }

task(:default).clear
task(:default => [:lint, :test])
