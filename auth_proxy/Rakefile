require "bundler/setup"

require "rake/testtask"
Rake::TestTask.new do |t|
  t.libs += ["models", "spec"]
  t.pattern = "spec/**/*_spec.rb"
end

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ["-I models", "-f documentation", "--color"]
end

begin
  require "yard"
  YARD::Rake::YardocTask.new do |t|
    # Delete the .svn folders that lead to permission problems when re-generating
    # existing documentation.
    t.before = lambda { `rm -rf /srv/developer/devdev/docs/**/.svn` }
    t.after = lambda { `rm -rf /srv/developer/devdev/docs/**/.svn` }
  end
rescue LoadError
  desc "You need the `yard` gem to generate documentation"
  task :yard
end
