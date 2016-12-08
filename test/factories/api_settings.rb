FactoryGirl.define do
  factory :api_setting, :class => "Api::Settings" do
    factory :custom_rate_limit_api_setting do
      rate_limit_mode "custom"
      rate_limits do
        [
          FactoryGirl.attributes_for(:api_rate_limit, :response_headers => true),
        ]
      end
    end
  end
end
