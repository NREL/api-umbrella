require "bundler/setup"

# Detect the source root directory.
API_UMBRELLA_SRC_ROOT = File.expand_path(__dir__)
if(!File.exist?(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella")))
  raise "The calculated root directory does not appear correct: #{API_UMBRELLA_SRC_ROOT}"
end

# Add our build directories to the $PATH. This ensures test and development
# dependencies (like nodejs/yarn) are on the path.
ENV["PATH"] = [
  "#{API_UMBRELLA_SRC_ROOT}/build/work/stage/opt/api-umbrella/embedded/bin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/stage/opt/api-umbrella/embedded/sbin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/test-env/bin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/test-env/sbin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/dev-env/bin",
  "#{API_UMBRELLA_SRC_ROOT}/build/work/dev-env/sbin",
  ENV.fetch("PATH"),
].join(":")

Dir.glob(File.join(API_UMBRELLA_SRC_ROOT, "scripts/rake/*.rake")).each { |r| import r }

task(:default).clear
task(:default => [:test])
