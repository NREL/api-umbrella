FactoryBot.define do
  factory :log_city_location do
    country "United States"
    region "CO"
    city "Golden"
    location("type" => "Point", "coordinates" => [-105.2433, 39.7146])
    updated_at { Time.now.utc }
  end
end
