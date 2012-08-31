ENV["RACK_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)

require "database_cleaner"
require "factory_girl"
require "nokogiri"
require "rack/test"
require "timecop"
require "yajl"

FactoryGirl.find_definitions

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.orm = "mongoid"
    DatabaseCleaner.clean
  end
end
