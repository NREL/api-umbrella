FactoryBot.define do
  factory :api_backend do
    sequence(:name) { |n| "Example #{n}" }
    backend_protocol { "http" }
    frontend_host { "localhost" }
    backend_host { "example.com" }
    balance_algorithm { "least_conn" }
    organization_name { "Example Org" }
    status_description { "Production" }

    servers do
      [FactoryBot.attributes_or_build(@build_strategy, :api_backend_server, :host => "example.com")]
    end

    url_matches do
      [FactoryBot.attributes_or_build(@build_strategy, :api_backend_url_match, :frontend_prefix => "/example", :backend_prefix => "/")]
    end

    factory :api_backend_with_settings do
      settings do
        FactoryBot.attributes_or_build(@build_strategy, :api_backend_settings)
      end
    end

    factory :api_backend_with_all_relationships do
      settings do
        FactoryBot.attributes_or_build(@build_strategy, :custom_rate_limit_api_backend_settings)
      end

      sub_settings do
        [
          FactoryBot.attributes_or_build(@build_strategy, :api_backend_sub_url_settings, {
            :settings => FactoryBot.attributes_or_build(@build_strategy, :custom_rate_limit_api_backend_settings),
          }),
        ]
      end

      rewrites do
        [FactoryBot.attributes_or_build(@build_strategy, :api_backend_rewrite)]
      end
    end

    factory :google_api_backend do
      sequence(:name) { |n| "Google #{n}" }
      backend_host { "google.com" }

      servers do
        [FactoryBot.attributes_or_build(@build_strategy, :api_backend_server, :host => "google.com")]
      end

      url_matches do
        [FactoryBot.attributes_or_build(@build_strategy, :api_backend_url_match, :frontend_prefix => "/google", :backend_prefix => "/")]
      end

      sub_settings do
        [
          FactoryBot.attributes_or_build(@build_strategy, :api_backend_sub_url_settings, {
            :settings => FactoryBot.attributes_or_build(@build_strategy, :api_backend_settings, {
              :required_roles => [
                "google-write",
              ],
            }),
          }),
        ]
      end

      factory :google_extra_url_match_api_backend do
        url_matches do
          [
            FactoryBot.attributes_or_build(@build_strategy, :api_backend_url_match, :frontend_prefix => "/google", :backend_prefix => "/"),
            FactoryBot.attributes_or_build(@build_strategy, :api_backend_url_match, :frontend_prefix => "/extra", :backend_prefix => "/"),
          ]
        end

        settings do
          FactoryBot.attributes_or_build(@build_strategy, :api_backend_settings, {
            :required_roles => [
              "google-extra-write",
            ],
          })
        end
      end
    end

    factory :yahoo_api_backend do
      sequence(:name) { |n| "Yahoo #{n}" }
      backend_host { "yahoo.com" }

      servers do
        [FactoryBot.attributes_or_build(@build_strategy, :api_backend_server, :host => "yahoo.com")]
      end

      url_matches do
        [FactoryBot.attributes_or_build(@build_strategy, :api_backend_url_match, :frontend_prefix => "/yahoo", :backend_prefix => "/")]
      end

      sub_settings do
        [
          FactoryBot.attributes_or_build(@build_strategy, :api_backend_sub_url_settings, {
            :settings => FactoryBot.attributes_or_build(@build_strategy, :api_backend_settings, {
              :required_roles => [
                "yahoo-write",
              ],
            }),
          }),
        ]
      end
    end

    factory :bing_api_backend do
      sequence(:name) { |n| "Bing #{n}" }
      backend_host { "bing.com" }

      servers do
        [FactoryBot.attributes_or_build(@build_strategy, :api_backend_server, :host => "bing.com")]
      end

      url_matches do
        [
          FactoryBot.attributes_or_build(@build_strategy, :api_backend_url_match, :frontend_prefix => "/bing/search", :backend_prefix => "/"),
          FactoryBot.attributes_or_build(@build_strategy, :api_backend_url_match, :frontend_prefix => "/bing/images", :backend_prefix => "/"),
          FactoryBot.attributes_or_build(@build_strategy, :api_backend_url_match, :frontend_prefix => "/bing/maps", :backend_prefix => "/"),
        ]
      end

      factory :bing_search_api_backend do
        url_matches do
          [FactoryBot.attributes_or_build(@build_strategy, :api_backend_url_match, :frontend_prefix => "/bing/search", :backend_prefix => "/")]
        end
      end
    end

    factory :empty_url_matches_api_backend do
      url_matches { [] }
      to_create { |instance| instance.save(:validate => false) }
    end
  end
end
