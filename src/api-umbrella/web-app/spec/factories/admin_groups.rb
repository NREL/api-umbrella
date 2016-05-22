# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :admin_group do
    sequence(:name) { |n| "Example#{n}" }
    api_scopes { [FactoryGirl.create(:api_scope)] }
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

    factory :yahoo_admin_group do
      api_scopes { [FactoryGirl.create(:yahoo_api_scope)] }
    end

    factory :bing_admin_group_single_all_scope do
      api_scopes { [FactoryGirl.create(:bing_all_api_scope)] }
    end

    factory :bing_admin_group_single_restricted_scope do
      api_scopes { [FactoryGirl.create(:bing_search_api_scope)] }
    end

    factory :bing_admin_group_multi_scope do
      api_scopes do
        [
          FactoryGirl.create(:bing_search_api_scope),
          FactoryGirl.create(:bing_images_api_scope),
          FactoryGirl.create(:bing_maps_api_scope),
        ]
      end
    end

    factory :amazon_admin_group_single_root_scope do
      api_scopes { [FactoryGirl.create(:amazon_api_scope)] }
    end

    factory :amazon_admin_group_single_sub_scope do
      api_scopes { [FactoryGirl.create(:amazon_books_api_scope)] }
    end

    factory :amazon_admin_group_multi_scope do
      api_scopes do
        [
          FactoryGirl.create(:amazon_api_scope),
          FactoryGirl.create(:amazon_books_api_scope),
        ]
      end
    end
  end
end
