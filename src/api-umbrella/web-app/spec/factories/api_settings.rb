# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :api_setting, :class => 'Api::Settings' do
    factory :custom_rate_limit_api_setting do
      rate_limit_mode "custom"
      rate_limits_attributes do
        [
          FactoryGirl.attributes_for(:api_rate_limit, {
            :duration => 60000,
            :limit_by => "ip",
            :limit => 500,
            :response_headers => true,
          }),
        ]
      end
    end
  end
end
