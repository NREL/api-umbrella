# Include serializable_hash customizations so that the data generated in tests
# also matches the app behavior of using "id" fields instead of "_id".
require File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/web-app/config/initializers/mongoid_serializable_id.rb")
FactoryBot.find_definitions
