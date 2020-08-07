FactoryBot.define do
  factory :api_backend_sub_url_settings do
    http_method { "POST" }
    sequence(:regex) { |n| "^/sub/#{n}/" }
  end
end
