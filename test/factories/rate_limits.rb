FactoryBot.define do
  factory :rate_limit do
    duration { 60000 }
    distributed { true }
    limit_by { "ip" }
    limit_to { 500 }
    response_headers { false }
  end
end
