# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :admin_group do
    name "Example"
    permission_ids [
      "analytics",
      "user_view",
      "user_manage",
      "admin_manage",
      "backend_manage",
      "backend_publish",
    ]

    trait :analytics_permission do
      permission_ids ["analytics"]
    end

    trait :user_view_permission do
      permission_ids ["user_view"]
    end

    trait :user_manage_permission do
      permission_ids ["user_manage"]
    end

    trait :admin_manage_permission do
      permission_ids ["admin_manage"]
    end

    trait :backend_manage_permission do
      permission_ids ["backend_manage"]
    end

    trait :backend_publish_permission do
      permission_ids ["backend_publish"]
    end

    factory :google_admin_group do
      api_scopes { [FactoryGirl.create(:google_api_scope)] }
    end
  end
end
