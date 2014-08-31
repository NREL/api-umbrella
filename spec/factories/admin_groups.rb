# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :admin_group do
    name "Example"
    access [
      "analytics",
      "user_view",
      "user_manage",
      "admin_manage",
      "backend_manage",
      "backend_publish",
    ]

    factory :google_admin_group do
      scope { FactoryGirl.create(:google_admin_scope) }
    end
  end
end
