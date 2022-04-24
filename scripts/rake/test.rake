require "rake/testtask"
Rake::TestTask.new do |t|
  # If the TESTS environment variable is set, accept that as a space-delimited
  # list of test files to run.
  if ENV["TESTS"]
    t.test_files = FileList[ENV.fetch("TESTS").split(" ")]
  else
    t.pattern = File.join(API_UMBRELLA_SRC_ROOT, "test/**/test_*.rb")
  end
  t.warning = false
end
