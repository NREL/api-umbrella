FactoryBot.define do
  factory :api_backend_http_header do
    key { "X-Custom" }
    value { "value" }
  end
end
