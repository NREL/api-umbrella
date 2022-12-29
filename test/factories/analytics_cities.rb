FactoryBot.define do
  factory :analytics_city do
    country { "United States" }
    region { "CO" }
    city { "Golden" }
    location { [-105.2433, 39.7146] }
  end
end
