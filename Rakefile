require "rake/testtask"
Rake::TestTask.new do |t|
  t.pattern = File.expand_path("../test/**/test_*.rb", __FILE__)
  t.warning = false
end

require "rubocop/rake_task"
RuboCop::RakeTask.new(:rubocop) do |t|
  t.patterns = [
    File.expand_path("../src/api-umbrella/web-app/**/*.rb", __FILE__),
    File.expand_path("../test/**/*.rb", __FILE__),
  ]
  t.options = [
    "--display-cop-names",
    "--extra-details",
  ]
end

task(:default).clear
task(:default => [:rubocop, :test])
