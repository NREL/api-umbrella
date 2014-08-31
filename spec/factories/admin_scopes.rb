# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :admin_scope do
    name "Example"
    host "localhost"
    path_prefix "/example"

    factory :google_admin_scope do
      path_prefix "/google"
    end
  end
end
