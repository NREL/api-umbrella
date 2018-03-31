FactoryBot.define do
  factory :api_setting, :class => "Api::Settings" do
    # Ensure at least one attribute is always present, so when testing null
    # values, the "settings" object at least gets created.
    disable_api_key false

    factory :custom_rate_limit_api_setting do
      rate_limit_mode "custom"
      rate_limits do
        [
          FactoryBot.attributes_for(:api_rate_limit, :response_headers => true),
        ]
      end
    end
  end
end
