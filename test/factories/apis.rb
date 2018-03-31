FactoryBot.define do
  factory :api do
    sequence(:name) { |n| "Example #{n}" }
    backend_protocol "http"
    frontend_host "localhost"
    backend_host "example.com"
    balance_algorithm "least_conn"

    servers do
      [FactoryBot.attributes_for(:api_server, :host => "example.com")]
    end

    url_matches do
      [FactoryBot.attributes_for(:api_url_match, :frontend_prefix => "/example", :backend_prefix => "/")]
    end

    factory :api_with_settings do
      settings do
        FactoryBot.attributes_for(:api_setting)
      end
    end

    factory :google_api do
      sequence(:name) { |n| "Google #{n}" }
      backend_host "google.com"

      servers do
        [FactoryBot.attributes_for(:api_server, :host => "google.com")]
      end

      url_matches do
        [FactoryBot.attributes_for(:api_url_match, :frontend_prefix => "/google", :backend_prefix => "/")]
      end

      sub_settings do
        [
          FactoryBot.attributes_for(:api_sub_setting, {
            :settings_attributes => FactoryBot.attributes_for(:api_setting, {
              :required_roles => [
                "google-write",
              ],
            }),
          }),
        ]
      end

      factory :google_extra_url_match_api do
        url_matches do
          [
            FactoryBot.attributes_for(:api_url_match, :frontend_prefix => "/google", :backend_prefix => "/"),
            FactoryBot.attributes_for(:api_url_match, :frontend_prefix => "/extra", :backend_prefix => "/"),
          ]
        end

        settings do
          FactoryBot.attributes_for(:api_setting, {
            :required_roles => [
              "google-extra-write",
            ],
          })
        end
      end
    end

    factory :yahoo_api do
      sequence(:name) { |n| "Yahoo #{n}" }
      backend_host "yahoo.com"

      servers do
        [FactoryBot.attributes_for(:api_server, :host => "yahoo.com")]
      end

      url_matches do
        [FactoryBot.attributes_for(:api_url_match, :frontend_prefix => "/yahoo", :backend_prefix => "/")]
      end

      sub_settings do
        [
          FactoryBot.attributes_for(:api_sub_setting, {
            :settings_attributes => FactoryBot.attributes_for(:api_setting, {
              :required_roles => [
                "yahoo-write",
              ],
            }),
          }),
        ]
      end
    end

    factory :bing_api do
      sequence(:name) { |n| "Bing #{n}" }
      backend_host "bing.com"

      servers do
        [FactoryBot.attributes_for(:api_server, :host => "bing.com")]
      end

      url_matches do
        [
          FactoryBot.attributes_for(:api_url_match, :frontend_prefix => "/bing/search", :backend_prefix => "/"),
          FactoryBot.attributes_for(:api_url_match, :frontend_prefix => "/bing/images", :backend_prefix => "/"),
          FactoryBot.attributes_for(:api_url_match, :frontend_prefix => "/bing/maps", :backend_prefix => "/"),
        ]
      end

      factory :bing_search_api do
        url_matches do
          [FactoryBot.attributes_for(:api_url_match, :frontend_prefix => "/bing/search", :backend_prefix => "/")]
        end
      end
    end

    factory :empty_url_matches_api do
      url_matches { [] }
      to_create { |instance| instance.save(:validate => false) }
    end
  end
end
