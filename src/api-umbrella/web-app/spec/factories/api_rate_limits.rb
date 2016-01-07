# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :api_rate_limit, :class => 'Api::RateLimit' do
    duration 60000
    limit_by "ip"
    limit 500
    response_headers false
  end
end
