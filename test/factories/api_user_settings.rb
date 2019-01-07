FactoryBot.define do
  factory :api_user_settings do
    factory :custom_rate_limit_api_user_settings do
      rate_limit_mode { "custom" }
      rate_limits do
        [
          FactoryBot.attributes_or_build(@build_strategy, :rate_limit, :response_headers => true),
        ]
      end
    end
  end
end
