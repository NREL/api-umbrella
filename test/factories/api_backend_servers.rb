FactoryGirl.define do
  factory :api_backend_server do
    id { SecureRandom.uuid }
    host "example.com"
    port 80
  end
end
