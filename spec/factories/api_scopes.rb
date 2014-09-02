# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :api_scope do
    name "Example"
    host "localhost"
    path_prefix "/example"

    factory :google_api_scope do
      path_prefix "/google"
    end
  end
end
