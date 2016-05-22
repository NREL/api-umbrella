# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :api_scope do
    name "Example"
    host "localhost"
    path_prefix "/example"

    factory :localhost_root_api_scope do
      path_prefix "/"
    end

    factory :google_api_scope do
      path_prefix "/google"
    end

    factory :yahoo_api_scope do
      path_prefix "/yahoo"
    end

    factory :extra_api_scope do
      path_prefix "/extra"
    end

    factory :bing_all_api_scope do
      path_prefix "/bing"
    end

    factory :bing_search_api_scope do
      path_prefix "/bing/search"
    end

    factory :bing_images_api_scope do
      path_prefix "/bing/images"
    end

    factory :bing_maps_api_scope do
      path_prefix "/bing/maps"
    end
  end
end
