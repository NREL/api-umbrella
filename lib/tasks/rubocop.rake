begin
  require 'rubocop/rake_task'
  Rubocop::RakeTask.new
rescue LoadError
  desc "You need the `rubocop` gem to run RuboCop"
  task :rubocop
end
