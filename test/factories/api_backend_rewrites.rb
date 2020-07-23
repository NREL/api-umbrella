FactoryBot.define do
  factory :api_backend_rewrite do
    matcher_type { "regex" }
    http_method { "any" }
    sequence(:frontend_matcher) { |n| "^/rewrite/#{n}/" }
    backend_replacement { "/bar" }
    sequence(:sort_order) { |n| n }
  end
end
