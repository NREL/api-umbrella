# Detect the source root directory.
ENV["API_UMBRELLA_SRC_ROOT"] = File.expand_path(__dir__)
if(!File.exist?(File.join(ENV.fetch("API_UMBRELLA_SRC_ROOT"), "src/api-umbrella")))
  raise "The calculated root directory does not appear correct: #{ENV.fetch("API_UMBRELLA_SRC_ROOT")}"
end

# Add our build directories to the $PATH. This ensures test and development
# dependencies (like nodejs/yarn) are on the path.
ENV["PATH"] = [
  "#{ENV.fetch("API_UMBRELLA_SRC_ROOT")}/build/work/stage/opt/api-umbrella/embedded/bin",
  "#{ENV.fetch("API_UMBRELLA_SRC_ROOT")}/build/work/stage/opt/api-umbrella/embedded/sbin",
  "#{ENV.fetch("API_UMBRELLA_SRC_ROOT")}/build/work/test-env/bin",
  "#{ENV.fetch("API_UMBRELLA_SRC_ROOT")}/build/work/test-env/sbin",
  "#{ENV.fetch("API_UMBRELLA_SRC_ROOT")}/build/work/dev-env/bin",
  "#{ENV.fetch("API_UMBRELLA_SRC_ROOT")}/build/work/dev-env/sbin",
  ENV.fetch("PATH"),
].join(":")
