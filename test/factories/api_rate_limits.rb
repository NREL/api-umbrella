FactoryBot.define do
  factory :api_rate_limit, :class => 'Api::RateLimit' do
    duration 60000
    accuracy 5000
    distributed true
    limit_by "ip"
    limit 500
    response_headers false
  end
end
