# Include serializable_hash customizations so that the data generated in tests
# also matches the app behavior of using "id" fields instead of "_id".
require File.expand_path("../../../../src/api-umbrella/web-app/config/initializers/mongoid_serializable_id.rb", __FILE__)

Dir["support/models/*.rb"].each { |f| require f }
Dir["support/models/**/*.rb"].each { |f| require f }
FactoryGirl.find_definitions
