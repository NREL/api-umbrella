FactoryGirl.define do
  factory :api_backend_url_match do
    id { SecureRandom.uuid }
    frontend_prefix "/example-frontend/"
    backend_prefix "/example-backend/"
  end
end
