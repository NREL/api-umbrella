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

    trait :analytics_access do
      access ["analytics"]
    end

    trait :user_view_access do
      access ["user_view"]
    end

    trait :user_manage_access do
      access ["user_manage"]
    end

    trait :admin_manage_access do
      access ["admin_manage"]
    end

    trait :backend_manage_access do
      access ["backend_manage"]
    end

    trait :backend_publish_access do
      access ["backend_publish"]
    end

    factory :google_admin_group do
      scope { FactoryGirl.create(:google_admin_scope) }
    end
  end
end
