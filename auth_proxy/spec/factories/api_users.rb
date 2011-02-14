require "api_user"

Factory.sequence :api_key do |n|
  "TESTING_KEY_#{n}"
end

Factory.define :api_user do |f|
  f.api_key { Factory.next(:api_key) }
  f.first_name "Testing"
  f.last_name "Key"
  f.email "testing_key@nrel.gov"
  f.website "http://nrel.gov/"
  f.roles []
end

Factory.define :disabled_api_user, :class => ApiUser do |f|
  f.api_key "DISABLED_KEY"
  f.first_name "Testing"
  f.last_name "Key"
  f.email "testing_key@nrel.gov"
  f.website "http://nrel.gov/"
  f.disabled_at Time.now
  f.roles []
end
