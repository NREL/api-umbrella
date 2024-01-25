FactoryBot.define do
  factory :admin_group do
    sequence(:name) { |n| "Example#{n}" }
    api_scopes { [ApiScope.find_or_create_by_instance!(FactoryBot.build(:api_scope))] }
    permission_ids do
      [
        "analytics",
        "user_view",
        "user_manage",
        "admin_view",
        "admin_manage",
        "backend_manage",
        "backend_publish",
      ]
    end

    trait :analytics_permission do
      permission_ids { ["analytics"] }
    end

    trait :user_view_permission do
      permission_ids { ["user_view"] }
    end

    trait :user_manage_permission do
      permission_ids { ["user_manage"] }
    end

    trait :user_view_and_manage_permission do
      permission_ids { ["user_view", "user_manage"] }
    end

    trait :admin_view_permission do
      permission_ids { ["admin_view"] }
    end

    trait :admin_manage_permission do
      permission_ids { ["admin_manage"] }
    end

    trait :admin_view_and_manage_permission do
      permission_ids { ["admin_view", "admin_manage"] }
    end

    trait :backend_manage_permission do
      permission_ids { ["backend_manage"] }
    end

    trait :backend_publish_permission do
      permission_ids { ["backend_publish"] }
    end

    factory :localhost_root_admin_group do
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryBot.build(:localhost_root_api_scope))] }
    end

    factory :google_admin_group do
      sequence(:name) { |n| "Google Admin Group #{n}" }
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope))] }
    end

    factory :yahoo_admin_group do
      sequence(:name) { |n| "Yahoo Admin Group #{n}" }
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope))] }
    end

    factory :google_and_yahoo_multi_scope_admin_group do
      sequence(:name) { |n| "Google & Yahoo Admin Group #{n}" }
      api_scopes do
        [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:google_api_scope)),
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:yahoo_api_scope)),
        ]
      end
    end

    factory :bing_admin_group_single_all_scope do
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryBot.build(:bing_all_api_scope))] }
    end

    factory :bing_admin_group_single_restricted_scope do
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryBot.build(:bing_search_api_scope))] }
    end

    factory :bing_admin_group_multi_scope do
      api_scopes do
        [
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:bing_search_api_scope)),
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:bing_images_api_scope)),
          ApiScope.find_or_create_by_instance!(FactoryBot.build(:bing_maps_api_scope)),
        ]
      end
    end

    factory :example_com_admin_group do
      api_scopes { [ApiScope.find_or_create_by_instance!(FactoryBot.build(:example_com_root_api_scope))] }
    end
  end
end
