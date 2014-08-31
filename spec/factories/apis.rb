# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :api do
    sequence(:name) { |n| "Example #{n}" }
    backend_protocol "http"
    frontend_host "localhost"
    backend_host "example.com"
    balance_algorithm "least_conn"

    servers do
      [FactoryGirl.attributes_for(:api_server, :host => "example.com", :port => 80)]
    end

    url_matches do
      [FactoryGirl.attributes_for(:api_url_match, :frontend_prefix => "/example", :backend_prefix => "/")]
    end

    factory :google_api do
      sequence(:name) { |n| "Google #{n}" }
      backend_host "google.com"

      servers do
        [FactoryGirl.attributes_for(:api_server, :host => "google.com", :port => 80)]
      end

      url_matches do
        [FactoryGirl.attributes_for(:api_url_match, :frontend_prefix => "/google", :backend_prefix => "/")]
      end

      factory :google_extra_url_match_api do
        url_matches do
          [
            FactoryGirl.attributes_for(:api_url_match, :frontend_prefix => "/google", :backend_prefix => "/"),
            FactoryGirl.attributes_for(:api_url_match, :frontend_prefix => "/extra", :backend_prefix => "/"),
          ]
        end
      end
    end

    factory :yahoo_api do
      sequence(:name) { |n| "Yahoo #{n}" }
      backend_host "yahoo.com"

      servers do
        [FactoryGirl.attributes_for(:api_server, :host => "yahoo.com", :port => 80)]
      end

      url_matches do
        [FactoryGirl.attributes_for(:api_url_match, :frontend_prefix => "/yahoo", :backend_prefix => "/")]
      end
    end
  end
end
