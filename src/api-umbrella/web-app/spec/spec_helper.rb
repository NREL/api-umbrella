# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
#
# Make sure the integration start processes support file gets required first,
# so it has an opportunity to set up it's callbacks to start processes first.
require Rails.root.join("spec/support/integration_start_processes.rb")
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Prevent test-unit from trying to run after running rspec tests manually:
# https://github.com/grosser/parallel_tests/issues/189
#
# TODO: This is likely due to our test-unit dependency in our Gemfile due to
# Rails 3.2 and Ruby 2.2 compatibility. Revisit this when we upgrade Rails.
Test::Unit::AutoRunner.need_auto_run = false if defined?(Test::Unit::AutoRunner)

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec

  config.infer_spec_type_from_file_location!

  # Don't filter backtraces
  config.backtrace_exclusion_patterns = []

  config.render_views
end
