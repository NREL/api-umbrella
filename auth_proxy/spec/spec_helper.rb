ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)

require "minitest/spec"
require "minitest/autorun"

require "database_cleaner"
require "rack/test"
require "factory_girl"
require "nokogiri"
require "yajl"
require "timecop"
Factory.find_definitions

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.orm = "mongoid"
    DatabaseCleaner.clean
  end
end
