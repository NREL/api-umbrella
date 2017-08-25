FactoryGirl.define do
  factory :api_backend_url_match do
    frontend_prefix "/example-frontend/"
    backend_prefix "/example-backend/"
  end
end
