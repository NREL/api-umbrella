FactoryBot.define do
  factory :api_backend_settings do
    # Ensure at least one attribute is always present, so when testing null
    # values, the "settings" object at least gets created.
    disable_api_key { false }

    factory :custom_rate_limit_api_backend_settings do
      rate_limit_mode { "custom" }
      rate_limits do
        [
          FactoryBot.attributes_or_build(@build_strategy, :rate_limit, :response_headers => true),
        ]
      end
    end
  end
end
