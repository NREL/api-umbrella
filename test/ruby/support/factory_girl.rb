Dir["support/models/*.rb"].each { |f| require f }
Dir["support/models/**/*.rb"].each { |f| require f }
FactoryGirl.find_definitions
