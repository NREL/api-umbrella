FactoryBot.define do
  factory :api_backend_server do
    host { "example.com" }
    sequence(:port) { |n| 80 + n }
  end
end
