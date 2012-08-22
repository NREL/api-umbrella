require "api_user"

FactoryGirl.define do
  sequence :api_key do |n|
    "TESTING_KEY_#{n}"
  end

  factory :api_user do
    api_key { generate(:api_key) }
    first_name "Testing"
    last_name "Key"
    email "testing_key@nrel.gov"
    website "http://nrel.gov/"
    roles []
  end

  factory :disabled_api_user, :class => ApiUser do
    api_key "DISABLED_KEY"
    first_name "Testing"
    last_name "Key"
    email "testing_key@nrel.gov"
    website "http://nrel.gov/"
    disabled_at Time.now
    roles []
  end
end
