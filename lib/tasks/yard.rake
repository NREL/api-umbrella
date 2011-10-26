begin
  require "yard"

  YARD::Rake::YardocTask.new
rescue LoadError
  desc "You need the `yard` gem to generate documentation"
  task :yard
end
